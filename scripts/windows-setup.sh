#!/bin/bash
# Windows-side setup under WSL2: Alacritty, the Nerd Font, and the Alacritty
# config link. Runs as the install command of the `windows-setup` dfutil tool,
# from the repo root. Never fails the run: every problem is a warning.
#
# Needs WSL interop. The distro name comes from $WSL_DISTRO_NAME, because
# `wsl.exe --list --running` can name the wrong distro when several exist.
set -u

warn() { echo "warning: $*" >&2; }

interop_ok=false
if [ "$(head -1 /proc/sys/fs/binfmt_misc/WSLInterop 2>/dev/null)" = enabled ]; then
  interop_ok=true
elif command -v powershell.exe >/dev/null 2>&1 &&
  powershell.exe -NonInteractive -c "exit 0" >/dev/null 2>&1; then
  interop_ok=true
fi
if [ "$interop_ok" = false ]; then
  warn "WSL interop is disabled, skipping Windows setup."
  warn "Add 'enabled=true' under [interop] in /etc/wsl.conf, run 'wsl --shutdown', and reopen."
  exit 0
fi

distro=${WSL_DISTRO_NAME:-}
[ -n "$distro" ] ||
  distro=$(powershell.exe -NonInteractive -c "wsl.exe --list --running --quiet" 2>/dev/null |
    tr -d '\r\0' | grep -v '^$' | head -1) || true
[ -n "$distro" ] ||
  distro=$(grep '^NAME=' /etc/os-release 2>/dev/null | cut -d'"' -f2 | tr ' ' '-') || true

repo=$PWD
toml=/alacritty/.config/alacritty/alacritty.toml
if [[ "$repo" =~ ^/mnt/([a-zA-Z])(/.*)$ ]]; then
  drive=${BASH_REMATCH[1]^^}
  rest=${BASH_REMATCH[2]}
  target="${drive}:${rest//\//\\}${toml//\//\\}"
else
  target="\\\\wsl.localhost\\${distro}${repo//\//\\}${toml//\//\\}"
fi

script=$(wslpath -w "$repo/windows-setup.ps1")
echo "Running Windows setup (Alacritty, font, config link)"
powershell.exe -NonInteractive -ExecutionPolicy Bypass \
  -File "$script" -AlacrittyTarget "$target" 2>&1 |
  tr -d '\r\0' | grep -v '^$' ||
  warn "PowerShell step had warnings (non-fatal)"
exit 0
