#!/bin/sh
# Add yazi's flavors and plugins with `ya pkg`. Runs as yazi's post_install.
# yazi/.linkignore keeps these directories out of the deployed package.
set -u

ya=${DFUTIL_BIN_DIR:+$DFUTIL_BIN_DIR/}ya
for pkg in \
  yazi-rs/flavors:catppuccin-mocha \
  yazi-rs/plugins:full-border \
  yazi-rs/plugins:git \
  yazi-rs/plugins:piper \
  imsi32/yatline \
  imsi32/yatline-catppuccin \
  imsi32/yatline-githead \
  ndtoan96/ouch \
  Rolv-Apneseth/starship; do
  "$ya" pkg add "$pkg" >/dev/null 2>&1 || true
done
"$ya" pkg install || { echo "ya pkg install failed; run it by hand" >&2; exit 1; }
