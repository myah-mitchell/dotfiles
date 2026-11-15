#!/bin/sh
# Nushell extras: the Catppuccin Mocha theme and an empty secrets.nu.
#
# Runs as a dfutil script tool. config.nu sources the theme, and env.nu sources
# secrets.nu. Nu resolves `source` at parse time, so a missing file is a
# startup error, which is why secrets.nu is created empty here.
set -u

dir=${XDG_CONFIG_HOME:-$HOME/.config}/nushell
mkdir -p "$dir/themes"

[ -e "$dir/secrets.nu" ] || : >"$dir/secrets.nu"

theme="$dir/themes/catppuccin_mocha.nu"
if [ ! -f "$theme" ]; then
  if curl -fsSL --connect-timeout 15 --retry 2 \
    "https://raw.githubusercontent.com/catppuccin/nushell/main/themes/catppuccin_mocha.nu" \
    -o "${theme}.tmp"; then
    mv "${theme}.tmp" "$theme"
  else
    rm -f "${theme}.tmp"
    echo "download failed: catppuccin/nushell theme" >&2
    exit 1
  fi
fi
