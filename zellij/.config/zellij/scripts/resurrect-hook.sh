#!/bin/sh
# Zellij post_command_discovery_hook: rewrites each pane's discovered command
# before it's saved for session resurrection.
#
# Zellij runs this through `sh -c` with the pane's argv, space-joined, in
# $RESURRECT_COMMAND, and saves whatever it prints (split on whitespace).
#
# A Claude Code pane started through the `claude` wrapper in .zshrc has
# `--session-id <uuid>` in its argv; it's saved as `claude --resume <uuid>` so
# resurrection reopens that conversation. Other flags are dropped. Every other
# command, and a `claude` with no session ID in its argv, passes through as is.

set -f
# shellcheck disable=SC2086  # word splitting is the point
set -- $RESURRECT_COMMAND

case "$1" in
  claude | */claude) ;;
  *)
    printf '%s\n' "$RESURRECT_COMMAND"
    exit 0
    ;;
esac

id=$(printf '%s\n' "$RESURRECT_COMMAND" |
  sed -nE 's/.*(--session-id|--resume|-r)[ =]([0-9a-fA-F-]{36})( .*)?$/\2/p')

if [ -n "$id" ]; then
  # /clear and /resume switch sessions without changing argv; the Claude Code
  # SessionStart hook (claude/.claude/scripts/claude-resurrect-map.py) records
  # the pane's current session under the argv ID.
  id=$(printf '%s' "$id" | tr 'A-F' 'a-f')
  map="${XDG_STATE_HOME:-$HOME/.local/state}/claude-resurrect/$id"
  if [ -r "$map" ]; then
    current=$(sed -nE '1{/^[0-9a-f-]{36}$/p;}' "$map")
    [ -n "$current" ] && id=$current
  fi
  printf 'claude --resume %s\n' "$id"
else
  printf '%s\n' "$RESURRECT_COMMAND"
fi
