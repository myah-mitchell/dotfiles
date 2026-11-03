#!/usr/bin/env bash
# git clean filter for the "homepath" attribute: folds a baked-in
# <home>/.config/zellij/scripts/ prefix back to the __DOTFILES_HOME__
# placeholder before content reaches the git index, so `git add` and
# `git commit` never stage a machine-specific path. Paired with
# homepath-smudge.sh (checkout side).
#
# Matches this machine's $HOME exactly (whatever it is), plus any Linux
# (/home/<user>), macOS (/Users/<user>), or root (/root) home, in case the file
# came from another machine. See "The homepath git filter" in CLAUDE.md for why
# config.kdl needs a real absolute path at all.
set -euo pipefail
home_re=$(printf '%s' "$HOME" | sed 's/[][\.*^$+?(){}|#/]/\\&/g')
sed -E \
  -e "s#${home_re}/\\.config/zellij/scripts/#__DOTFILES_HOME__/.config/zellij/scripts/#g" \
  -e 's#(/home/[^/[:space:]"]+|/Users/[^/[:space:]"]+|/root)/\.config/zellij/scripts/#__DOTFILES_HOME__/.config/zellij/scripts/#g'
