#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""One-line CPU / memory / disk / battery usage for the zjstatus bar.

Prints a single Nerd-Font-glyph line, e.g.:

    󰘚 12% 󰍛 45% 󰋊 67% 󰂀 72%

    󰘚 {cpu}% 󰍛 {memory}% 󰋊 {disk /}% {battery icon} {battery}%

Icons are followed by a space — JetBrainsMono Nerd Font Propo renders the wide
MDI glyphs over the next character otherwise.

- CPU is averaged over the window since the previous refresh: the raw
  /proc/stat counters are kept in the cache and diffed on the next run, so a
  60-second cadence reports the true mean over that minute instead of an
  instant sample. The very first run (no counters yet) takes a quick 0.25 s
  two-point sample.
- Memory is used% from /proc/meminfo (MemTotal - MemAvailable).
- Disk is used% of / (df-style: used / (used + available)).
- Battery reuses get_battery_state() from battery.py (the Zelda heart tracker,
  kept alongside as a swappable alternative). The icon shows the charge level,
  or a charging bolt when plugged in; the segment is hidden entirely on
  devices without a battery. On WSL that read shells out to powershell.exe
  (~3 s), which is exactly what the cache absorbs.
- The rendered line is cached in ~/.cache/zellij-sysinfo.json for CACHE_TTL
  seconds, deduping the work across zjstatus instances (one per open tab). On
  any read failure the last good line is served.
"""

import json
import os
import sys
import time
from pathlib import Path

sys.dont_write_bytecode = True  # no __pycache__ in the stowed scripts dir
sys.path.insert(0, str(Path(__file__).resolve().parent))
from battery import get_battery_state

CACHE_FILE = Path.home() / ".cache" / "zellij-sysinfo.json"
CACHE_TTL = 60
FALLBACK = "\U000F029A --"  # 󰊚 gauge — no data and no cache

# Material Design Icons (Nerd Font PUA plane), matching the rest of the bar.
ICON_CPU = "\U000F061A"       # 󰘚 chip
ICON_MEM = "\U000F035B"       # 󰍛 memory
ICON_DISK = "\U000F02CA"      # 󰋊 harddisk
ICON_CHARGING = "\U000F0084"  # 󰂄 battery-charging
ICON_BATTERY = [              # discharging, by charge decile
    "\U000F008E",  # 󰂎 battery-outline (< 10%)
    "\U000F007A",  # 󰁺 battery-10
    "\U000F007B",  # 󰁻 battery-20
    "\U000F007C",  # 󰁼 battery-30
    "\U000F007D",  # 󰁽 battery-40
    "\U000F007E",  # 󰁾 battery-50
    "\U000F007F",  # 󰁿 battery-60
    "\U000F0080",  # 󰂀 battery-70
    "\U000F0081",  # 󰂁 battery-80
    "\U000F0082",  # 󰂂 battery-90
    "\U000F0079",  # 󰁹 battery (full)
]


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


def read_cpu_counters():
    """Returns (total, idle) jiffies from the aggregate cpu line of /proc/stat."""
    with open("/proc/stat") as f:
        fields = [int(x) for x in f.readline().split()[1:9]]
    # user nice system idle iowait irq softirq steal
    return sum(fields), fields[3] + fields[4]


def cpu_percent(prev):
    """CPU usage since `prev` counters, or a quick two-point sample without them."""
    if not prev:
        prev = read_cpu_counters()
        time.sleep(0.25)
    total, idle = read_cpu_counters()
    dtotal = total - prev[0]
    didle = idle - prev[1]
    pct = 100 * (1 - didle / dtotal) if dtotal > 0 else 0
    return pct, (total, idle)


def mem_percent():
    info = {}
    with open("/proc/meminfo") as f:
        for line in f:
            key, value = line.split(":")
            info[key] = int(value.split()[0])
    return 100 * (1 - info["MemAvailable"] / info["MemTotal"])


def disk_percent(path="/"):
    st = os.statvfs(path)
    used = st.f_blocks - st.f_bfree
    return 100 * used / (used + st.f_bavail)


def main():
    cache = load_cache()

    if cache.get("ts", 0) + CACHE_TTL > time.time() and "line" in cache:
        print(cache["line"])
        return

    try:
        cpu, counters = cpu_percent(cache.get("cpu"))
        parts = [
            f"{ICON_CPU} {round(cpu)}%",
            f"{ICON_MEM} {round(mem_percent())}%",
            f"{ICON_DISK} {round(disk_percent())}%",
        ]
        state = get_battery_state()
        if state is not None:  # devices without a battery skip the segment
            bat, discharging = state
            bat_icon = ICON_BATTERY[int(bat * 10)] if discharging else ICON_CHARGING
            parts.append(f"{bat_icon} {round(bat * 100)}%")
        line = " ".join(parts)
    except Exception:
        # Keep showing the last good line; retry on the next poll.
        print(cache.get("line", FALLBACK))
        return

    save_cache({"ts": time.time(), "line": line, "cpu": counters})
    print(line)


if __name__ == "__main__":
    main()
