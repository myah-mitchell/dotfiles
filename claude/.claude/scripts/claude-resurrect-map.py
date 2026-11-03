#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Tracks which conversation a Claude Code pane is on, for Zellij resurrection.

Registered as the `SessionStart` hook in claude/.claude/settings.json. Zellij's
post_command_discovery_hook (zellij/.config/zellij/scripts/resurrect-hook.sh)
only sees a pane's argv, so it can only resume the session ID the `claude`
process was started with (`--session-id <uuid>` from the zsh wrapper, or
`--resume <uuid>` after a resurrection). `/clear` and `/resume` switch to a
different session without changing argv.

This hook bridges that: it finds the session ID in its ancestor `claude`
process's argv and records the current session under it, as
$XDG_STATE_HOME/claude-resurrect/<argv-id> holding the current ID. When the
two match again, the file is removed. resurrect-hook.sh reads the file.

SessionStart stdout is added to Claude's context, so this prints nothing, and
it swallows every failure and always exits 0.
"""

import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

UUID = re.compile(r"^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$")
ID_FLAGS = {"--session-id", "--resume", "-r"}
MAX_HOPS = 10
PRUNE_AFTER_DAYS = 90


def state_dir():
    base = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    return Path(base) / "claude-resurrect"


def argv_session_id(argv):
    """The session ID passed on a claude command line, or None."""
    for i, arg in enumerate(argv):
        flag, eq, value = arg.partition("=")
        if flag in ID_FLAGS:
            if not eq:
                value = argv[i + 1] if i + 1 < len(argv) else ""
            if UUID.match(value):
                return value.lower()
    return None


def ancestor_claude_argv():
    """argv of the nearest ancestor process whose executable is named claude."""
    pid = os.getppid()
    for _ in range(MAX_HOPS):
        if pid <= 1:
            return None
        out = subprocess.run(
            ["ps", "-o", "ppid=,args=", "-p", str(pid)],
            capture_output=True,
            text=True,
            timeout=5,
        ).stdout.strip()
        if not out:
            return None
        ppid, _, args = out.partition(" ")
        argv = args.split()
        if argv and os.path.basename(argv[0]) == "claude":
            return argv
        pid = int(ppid)
    return None


def prune(directory):
    cutoff = time.time() - PRUNE_AFTER_DAYS * 86400
    for entry in directory.iterdir():
        if entry.stat().st_mtime < cutoff:
            entry.unlink(missing_ok=True)


def main():
    try:
        current = str(json.load(sys.stdin).get("session_id") or "").lower()
        if not UUID.match(current):
            return
        argv = ancestor_claude_argv()
        original = argv_session_id(argv) if argv else None
        if not original:
            return

        directory = state_dir()
        target = directory / original
        if current == original:
            target.unlink(missing_ok=True)
            return

        directory.mkdir(parents=True, exist_ok=True)
        tmp = target.with_suffix(".tmp")
        tmp.write_text(current + "\n")
        tmp.replace(target)
        prune(directory)
    except Exception:
        pass


if __name__ == "__main__":
    main()
    sys.exit(0)
