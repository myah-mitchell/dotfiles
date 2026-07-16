#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Bridges Claude Code's Notification hook into the zjstatus notification pill.

Registered (with no matcher — catch-all) as the `Notification` hook in
claude/.claude/settings.json, so this runs on every notification event and
does its own filtering here instead of relying on Claude Code's matcher.

Edit NOTIFY_TYPES below to change which notification types surface in the
zjstatus pill — see Claude Code's hooks docs for the full set of
notification_type values (e.g. auth_success, elicitation_dialog, ...).

Forwards a match via `zellij pipe "zjstatus::notify::<message>"`, which is
zjstatus's own pipe protocol for pushing into its notifications widget
(already wired up in config.kdl/default.kdl — nothing to configure there).

This is a side-effect-only hook (Notification supports no decision control),
so every failure path is swallowed and the script always exits 0 — a broken
zellij, a missing session, or a malformed payload must never surface as a
Claude Code error.
"""

import json
import os
import subprocess
import sys
from pathlib import Path

NOTIFY_TYPES = {"idle_prompt", "permission_prompt"}

MAX_MESSAGE_LEN = 80


def main():
    try:
        if not os.environ.get("ZELLIJ"):
            return  # not running inside a zellij session/pane

        payload = json.load(sys.stdin)
        if payload.get("notification_type") not in NOTIFY_TYPES:
            return

        cwd = payload.get("cwd") or ""
        label = Path(cwd).name or "claude"
        message = str(payload.get("message") or "").replace("\n", " ").strip()

        text = f"{label}: {message}" if message else label
        if len(text) > MAX_MESSAGE_LEN:
            text = text[: MAX_MESSAGE_LEN - 1] + "…"

        subprocess.run(
            ["zellij", "pipe", f"zjstatus::notify::{text}"],
            timeout=5,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except Exception:
        pass


if __name__ == "__main__":
    main()
    sys.exit(0)
