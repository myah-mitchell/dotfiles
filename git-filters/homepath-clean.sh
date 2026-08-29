#!/usr/bin/env bash
# git clean filter for the "homepath" attribute — normalizes any machine's
# baked-in /home/<user>/.config/zellij/scripts/ prefix to a stable placeholder
# before content reaches the git index, so `git add`/`git commit` never stage
# a machine-specific path. Paired with homepath-smudge.sh (checkout side).
# See CLAUDE.md "Config deployment: hand-rolled linker" for why config.kdl
# needs a real absolute path at all (nvim/autocmds.lua had the same problem
# but computes its own path at runtime instead — it's Lua, not static data).
set -euo pipefail
sed -E 's#/home/[^/[:space:]"]+/\.config/zellij/scripts/#__DOTFILES_HOME__/.config/zellij/scripts/#g'
