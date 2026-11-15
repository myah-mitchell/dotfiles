#!/bin/sh
# Install JetBrainsMono Nerd Font (NF, NFM, NFP; not the NL variants) into
# ~/.local/share/fonts. Native Linux only; under WSL2 the font goes in on the
# Windows side through windows-setup.ps1.
set -eu

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsSL --connect-timeout 30 --max-time 600 --retry 2 \
  "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" \
  -o "$tmp/JetBrainsMono.zip"
unzip -q "$tmp/JetBrainsMono.zip" -d "$tmp/fonts"

dest=${XDG_DATA_HOME:-$HOME/.local/share}/fonts
mkdir -p "$dest"
find "$tmp/fonts" -name 'JetBrainsMonoNerdFont*.ttf' -exec cp {} "$dest/" \;
fc-cache -f "$dest" 2>/dev/null || true
