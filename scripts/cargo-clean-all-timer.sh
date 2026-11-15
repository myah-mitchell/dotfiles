#!/bin/sh
# Schedule cargo-clean-all with a weekly systemd user timer.
#
# Usage: cargo-clean-all-timer.sh install | remove
# Runs as the cargo-clean-all tool's post_install and uninstall. Deletes the
# target/ directory of every Cargo project not compiled in the last 30 days.
# ~/.local, ~/.cache, ~/.cargo, and ~/.rustup are skipped: Neovim plugins such
# as blink.cmp keep prebuilt libraries in a target/ directory under ~/.local.
#
# The units are written as real files, not links, because `systemctl enable`
# refuses unit files that are symlinks pointing outside its search path.
set -u

unit_dir=${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user
bin=${DFUTIL_BIN_DIR:-$HOME/.local/bin}

case ${1:-} in
  remove)
    systemctl --user disable --now cargo-clean-all.timer >/dev/null 2>&1 || true
    rm -f "$unit_dir/cargo-clean-all.service" "$unit_dir/cargo-clean-all.timer"
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    exit 0
    ;;
  install) ;;
  *) echo "usage: cargo-clean-all-timer.sh install | remove" >&2; exit 2 ;;
esac

if ! systemctl --user show-environment >/dev/null 2>&1; then
  echo "no systemd user session; skipping the cargo-clean-all timer" >&2
  echo "run by hand: $bin/cargo-clean-all --yes --keep-days 30 --skip ~/.local --skip ~/.cache --skip ~/.cargo --skip ~/.rustup ~" >&2
  exit 0
fi

mkdir -p "$unit_dir"
cat >"$unit_dir/cargo-clean-all.service" <<UNIT
[Unit]
Description=Delete stale Cargo target directories

[Service]
Type=oneshot
ExecStart=$bin/cargo-clean-all --yes --keep-days 30 --skip %h/.local --skip %h/.cache --skip %h/.cargo --skip %h/.rustup %h
Nice=19
IOSchedulingClass=idle
UNIT
cat >"$unit_dir/cargo-clean-all.timer" <<'UNIT'
[Unit]
Description=Weekly cleanup of stale Cargo target directories

[Timer]
OnCalendar=weekly
Persistent=true
RandomizedDelaySec=1h

[Install]
WantedBy=timers.target
UNIT
systemctl --user daemon-reload
systemctl --user enable --now cargo-clean-all.timer
