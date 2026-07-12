#!/usr/bin/env bash
# git smudge filter for the "homepath" attribute — expands the
# __DOTFILES_HOME__ placeholder back to this machine's real $HOME on
# checkout, so the working-tree copy (symlinked straight into $HOME) stays
# functional. Paired with homepath-clean.sh (add/commit side).
set -euo pipefail
home_escaped="${HOME//&/\\&}"
sed -E "s#__DOTFILES_HOME__/\\.config/zellij/scripts/#${home_escaped}/.config/zellij/scripts/#g"
