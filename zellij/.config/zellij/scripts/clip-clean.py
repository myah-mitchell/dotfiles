#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Clipboard filter: strips Nerd Font icon glyphs before writing to the system
clipboard, so pasted prompt/status-bar output (branch icons, git status
pills, etc.) doesn't turn into tofu boxes on a machine without the font.

Used as Zellij's `copy_command` (reads the selection on stdin) and can also
be called directly, e.g. from Neovim's clipboard `copy` handler.

Nerd Fonts pack their icons into the three Unicode Private Use Areas, which
have no assigned meaning outside a font that specifically maps them — that's
exactly the set to drop. Everything else (real text, emoji, accented
characters) is passed through untouched, including whitespace, since mangling
that would corrupt copied code indentation.

REPLACEMENTS covers the Starship prompt glyphs specifically, since the prompt
line is by far the most commonly copied piece of terminal output (it's in
every shared command transcript). Each entry was derived straight from
starship.toml's symbol/format keys, so the label matches what the icon
actually stands for there (os.symbols keys -> distro name, language module
symbols -> a short [tag], etc). success_symbol/error_symbol share one glyph
in starship.toml (only the color differs) and so do the four vimcmd_*
variants, so at most one replacement can be picked per glyph regardless —
color info doesn't survive a terminal copy anyway, so this matches how
Starship's own default (non-Nerd-Font) symbols work: one glyph per
success/error, one per vim-mode-ish state ('>' vs '<'). Keys are written as
\\uXXXX/\\UXXXXXXXX escapes rather than literal glyphs since the raw
Private-Use-Area characters don't reliably round-trip through every editor.

Everything else — zjstatus mode/tab pill decorations, powerline separators,
weather/battery/sysinfo icons — isn't in this table and just gets dropped by
PUA_RANGES below. Those live in a status bar rather than scrollback text, so
they're rarely what someone actually selects and copies. To extend this
table, find the glyph's codepoint (e.g. `python3 -c "print(hex(ord(ch)))"`)
and add a `"\\uXXXX": "label"` entry.

"""

import re
import subprocess
import sys

REPLACEMENTS = {
    "󰆅": "jobs:",     # running jobs symbol
    "": "duration:", # task duration symbol
    "": "branch:",   # git branch symbol
    "": ">",         # character:success_symbol, character:error_symbol (same glyph)
    "": "| "
}

PUA_RANGES = re.compile(
    "["
    "\U0000E000-\U0000F8FF"  # BMP Private Use Area
    "\U000F0000-\U000FFFFD"  # Supplementary Private Use Area-A
    "\U00100000-\U0010FFFD"  # Supplementary Private Use Area-B
    "]"
)

def is_wsl():
    try:
        with open("/proc/version") as f:
            return "microsoft" in f.read().lower()
    except OSError:
        return False


def clipboard_command():
    if is_wsl():
        return ["/mnt/c/Windows/System32/clip.exe"]
    if sys.platform == "darwin":
        return ["pbcopy"]
    if subprocess.run(["which", "wl-copy"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
        return ["wl-copy"]
    return ["xclip", "-selection", "clipboard"]


def main():
    text = sys.stdin.buffer.read().decode("utf-8", errors="ignore")
    for glyph, label in REPLACEMENTS.items():
        text = text.replace(glyph, label)
    cleaned = PUA_RANGES.sub("", text)
    # clip.exe interprets piped stdin using the active OEM codepage unless it's
    # UTF-16LE, so a plain UTF-8 write comes out double-encoded garbage on paste.
    encoding = "utf-16-le" if is_wsl() else "utf-8"
    subprocess.run(clipboard_command(), input=cleaned.encode(encoding))


if __name__ == "__main__":
    main()
