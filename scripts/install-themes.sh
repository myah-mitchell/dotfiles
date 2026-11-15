#!/bin/sh
# Download the Catppuccin Mocha themes for bat, eza, and zsh-syntax-highlighting.
#
# Runs as a dfutil script tool. Each file is fetched only when missing, through
# a temp file so a failed download never leaves a partial theme behind.
# The themes are Mocha only: they follow the upstream ports, not the active
# dfutil palette.
set -u

config=${XDG_CONFIG_HOME:-$HOME/.config}
status=0

fetch() {
  url=$1
  dest=$2
  [ -f "$dest" ] && return 0
  mkdir -p "$(dirname "$dest")"
  if curl -fsSL --connect-timeout 15 --retry 2 "$url" -o "${dest}.tmp"; then
    mv "${dest}.tmp" "$dest"
  else
    rm -f "${dest}.tmp"
    echo "download failed: $url" >&2
    status=1
  fi
}

fetch "https://github.com/catppuccin/bat/raw/main/themes/Catppuccin%20Mocha.tmTheme" \
  "$config/bat/themes/Catppuccin Mocha.tmTheme"
fetch "https://raw.githubusercontent.com/catppuccin/eza/main/themes/mocha/catppuccin-mocha-mauve.yml" \
  "$config/eza/theme.yml"
fetch "https://raw.githubusercontent.com/catppuccin/zsh-syntax-highlighting/main/themes/catppuccin_mocha-zsh-syntax-highlighting.zsh" \
  "$config/zsh/themes/catppuccin_mocha-zsh-syntax-highlighting.zsh"

# bat only sees new themes after a cache rebuild.
bat cache --build >/dev/null 2>&1 || echo "bat cache --build failed" >&2
exit "$status"
