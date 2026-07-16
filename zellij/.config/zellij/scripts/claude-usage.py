#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Claude Code usage gauge for the zjstatus bar.

Prints a single line, e.g.:

    󰥔 15.5K → 05:00  󰸗 69.5K/wk  󰆘 2.1M all
    󰥔 idle  󰸗 69.5K/wk  󰆘 2.1M all   (no active 5-hour block)

Sourced from `ccusage` (github.com/ryoppippi/ccusage), which reconstructs
Claude Code's rolling 5-hour billing blocks and weekly usage windows by
parsing local ~/.claude/projects/*/*.jsonl session logs. This is a
local-log-derived ESTIMATE, not a live read of Anthropic's account-level
rate limits — there is no public API for that, so the numbers approximate
but won't be pixel-perfect against claude.ai.

- 󰥔 segment: tokens used in the current active 5-hour block, and the local
  clock time it resets at (endTime). "idle" when there's no active block
  (i.e. no Claude Code activity in the last 5 hours).
- 󰸗 segment: tokens used so far in the current calendar week.
- 󰆘 segment: all-time total tokens across all local session history.

Always uses the pinned local `ccusage` binary (installed by install_ccusage()
in install.sh) with --offline, never `npx ccusage@latest` — this script is
polled every command_claudeusage_interval seconds by zjstatus, so it must
never depend on network or npm registry resolution.

On any read failure, the last cached line is reused (battery.py/sysinfo.py's
pattern), so the pill never shows a traceback or error state.
"""

import json
import shutil
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

CACHE_FILE = Path.home() / ".cache" / "zellij-claude-usage.json"
CACHE_TTL = 60  # matches command_claudeusage_interval; dedupes ccusage spawns across tabs
CCUSAGE_TIMEOUT = 10  # seconds; a hung ccusage process must not wedge the poll

ICON_BLOCK = "\U000F0954"  # 󰥔 clock — active 5-hour block
ICON_WEEK = "\U000F0E17"  # 󰸗 calendar-week
ICON_TOTAL = "\U000F0198"  # 󰆘 chart/total

FALLBACK_LINE = "\U000F029A --"  # 󰊚 gauge — no data and no cache (reuses sysinfo.py's fallback icon)


def ccusage_bin():
    local_bin = Path.home() / ".local" / "bin" / "ccusage"
    if local_bin.exists():
        return str(local_bin)
    return shutil.which("ccusage")


def run_ccusage(binary, *args):
    out = subprocess.run(
        [binary, *args, "--json", "--offline"],
        capture_output=True,
        text=True,
        timeout=CCUSAGE_TIMEOUT,
        check=True,
    )
    return json.loads(out.stdout)


def format_tokens(n):
    if n >= 1_000_000:
        return f"{n / 1_000_000:.1f}M"
    if n >= 1_000:
        return f"{n / 1_000:.1f}K"
    return str(n)


def format_reset_time(iso_str):
    dt = datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
    return dt.astimezone().strftime("%H:%M")


def build_line(binary):
    blocks = run_ccusage(binary, "blocks", "--active").get("blocks", [])
    weekly = run_ccusage(binary, "weekly")

    if blocks:
        block = blocks[0]
        block_part = f"{ICON_BLOCK} {format_tokens(block['totalTokens'])} → {format_reset_time(block['endTime'])}"
    else:
        block_part = f"{ICON_BLOCK} idle"

    week_entries = weekly.get("weekly", [])
    week_tokens = week_entries[-1]["totalTokens"] if week_entries else 0
    all_time_tokens = weekly.get("totals", {}).get("totalTokens", 0)

    return (
        f"{block_part}  "
        f"{ICON_WEEK} {format_tokens(week_tokens)}/wk  "
        f"{ICON_TOTAL} {format_tokens(all_time_tokens)} all"
    )


def load_cache():
    try:
        return json.loads(CACHE_FILE.read_text())
    except (OSError, ValueError):
        return {}


def save_cache(cache):
    try:
        CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
        CACHE_FILE.write_text(json.dumps(cache))
    except OSError:
        pass


def main():
    cache = load_cache()
    if cache.get("ts", 0) + CACHE_TTL > time.time() and "line" in cache:
        print(cache["line"])
        return

    try:
        binary = ccusage_bin()
        if not binary:
            raise RuntimeError("ccusage not found")
        line = build_line(binary)
    except Exception:
        line = cache.get("line") or FALLBACK_LINE
        print(line)
        return

    save_cache({"ts": time.time(), "line": line})
    print(line)


if __name__ == "__main__":
    main()
