#!/usr/bin/env bash
# git clean filter for the "homepath" attribute — normalizes any machine's
# baked-in /home/<user>/.config/zellij/scripts/ prefix to a stable placeholder
# before content reaches the git index, so `git add`/`git commit` never stage
# a machine-specific path. Paired with homepath-smudge.sh (checkout side).
# See CLAUDE.md "Config deployment: hand-rolled linker" for why these two
# files (zellij/config.kdl, nvim/autocmds.lua) need real absolute paths at all.
set -euo pipefail
sed -E 's#/home/[^/[:space:]"]+/\.config/zellij/scripts/#__DOTFILES_HOME__/.config/zellij/scripts/#g'
