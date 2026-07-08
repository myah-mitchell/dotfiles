#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Battery gauge for the zjstatus bar, rendered as a row of Zelda-style hearts.

Prints a single Nerd-Font-glyph line, e.g.:

    󱐮 󰋑 󰋑 󰋑 󰋕 (full hearts, discharging endcap)
    12% 󱐲 󰋕 󰋕 󰋕 󰋕 (low charge, percentage shown, discharging endcap)

Each of MAX_HEARTS hearts represents an equal share of charge (full/half/
empty), Legend-of-Zelda style. The first or last heart is swapped for a
"damage" variant that also encodes charging vs. discharging, so the icon
alone conveys both charge level and direction:

- >= 34% charge: hearts only, no numeric percentage.
- <  34% charge: percentage is prefixed, since a couple of hearts alone
  doesn't convey "how close to empty" precisely enough to act on.
- Sourced from get_battery_state(), which is also imported by sysinfo.py so
  both bar segments agree on the current charge/direction.
- On WSL, /sys/class/power_supply has no host battery, so charge state is
  fetched via powershell.exe (Win32_Battery over CIM) and cached for
  CACHE_TTL seconds to hide that ~seconds-scale interop cost from every
  zjstatus instance polling this script.
- On any read failure, the last cached line is reused (falling back to a
  full, non-discharging heart row if there's no cache yet), so the bar never
  shows an error state.
"""

import glob
import json
import subprocess
import sys
import time
from math import floor
from pathlib import Path

MAX_HEARTS = 5
CACHE_FILE = Path.home() / ".cache" / "zellij-battery.json"
CACHE_TTL = 60  # dedupes the slow powershell.exe interop across zjstatus instances


def render_hearts(pct, max_hearts, discharging):
    hearts = max_hearts * pct
    partial = hearts - floor(hearts)

    full_hearts = floor(hearts) + round(partial)
    # A half heart only when there's a real fraction that didn't round up to
    # full — an exact integer (e.g. 60% of 5 hearts) gets no half.
    half_hearts = 1 if 0 < partial and round(partial) == 0 else 0
    empty_hearts = max_hearts - full_hearts - half_hearts

    chars = [
        *'󰋑' * full_hearts,
        *'󰛞' * half_hearts,
        *'󰋕' * empty_hearts,
    ]

    if chars[-1] == '󰋕':
        chars[-1] = '󱐲' if discharging else '󱐱'
    elif chars[-1] == '󰋑':
        chars[-1] = '󱐯' if discharging else '󱐮'
    elif chars[0] == '󰋑':
        chars[0] = '󱐯' if discharging else '󱐮'
    else:
        raise ValueError("Invalid state")

    return \
        (f'{floor(pct * 100)}% ' if pct <= 0.33 else '') \
        + ' '.join(chars) \
        + ' '


def is_wsl():
    try:
        with open("/proc/version") as f:
            return "microsoft" in f.read().lower()
    except OSError:
        return False


def get_wsl_battery_state():
    """WSL doesn't expose the host battery under /sys/class/power_supply, so ask
    Windows for it via powershell.exe interop (Win32_Battery over CIM).
    Returns None when the host has no battery (or the interop fails)."""
    try:
        shout = subprocess.check_output(
            [
                "powershell.exe", "-NoProfile", "-Command",
                "Get-CimInstance -ClassName Win32_Battery | ConvertTo-Json -Compress",
            ],
            stderr=subprocess.DEVNULL,
        )
    except (subprocess.CalledProcessError, FileNotFoundError, OSError):
        return None

    text = shout.decode("utf-8", errors="ignore").strip()
    if not text:
        return None

    data = json.loads(text)
    if isinstance(data, list):
        if not data:
            return None
        data = data[0]

    pct = data["EstimatedChargeRemaining"] / 100
    discharging = data["BatteryStatus"] == 1

    return pct, discharging


def get_battery_state():
    """Returns (pct, discharging), or None when no battery is present
    (e.g. desktop Ubuntu, or a WSL host with no battery of its own)."""
    if sys.platform == "darwin":
        shout = subprocess.check_output("pmset -g ps | grep -o '[0-9]\\+%; [^;]\\+'", shell=True)
        binput = str(shout, 'utf-8').strip().split("; ")

        if binput[0] == "AC Power":
            return 1.0, False

        return int(binput[0][:-1]) / 100, binput[1] == "discharging"

    if is_wsl():
        return get_wsl_battery_state()

    battery_dirs = sorted(glob.glob("/sys/class/power_supply/BAT*"))
    if not battery_dirs:
        return None

    battery_dir = battery_dirs[0]
    with open(f"{battery_dir}/capacity") as f:
        pct = int(f.read().strip()) / 100
    with open(f"{battery_dir}/status") as f:
        discharging = f.read().strip().lower() == "discharging"

    return pct, discharging


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
    if "--test" in sys.argv:
        for i in range(1, 101, 1):
            print(f"{i}%\t{render_hearts(i / 100, MAX_HEARTS, i % 2 == 0)}")
        return

    cache = load_cache()
    if cache.get("ts", 0) + CACHE_TTL > time.time() and "line" in cache:
        print(cache["line"])
        return

    try:
        # No battery renders as full hearts — Link at full health on wall power.
        pct, discharging = get_battery_state() or (1.0, False)
        line = render_hearts(pct, MAX_HEARTS, discharging)
    except Exception:
        # Keep showing the last good reading; retry on the next poll.
        line = cache.get("line") or render_hearts(1.0, MAX_HEARTS, False)
        print(line)
        return

    save_cache({"ts": time.time(), "line": line})
    print(line)

if __name__ == '__main__':
    main()