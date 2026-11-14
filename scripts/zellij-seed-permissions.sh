#!/bin/sh
# Pre-approve a Zellij plugin's permission scopes, so it does not sit inert
# waiting for a prompt in a size-1 borderless pane.
#
# Usage: zellij-seed-permissions.sh <plugin.wasm> <scope>...
# Runs as a dfutil post_install hook; DFUTIL_PREFIX says where the plugin links to.
#
# Zellij keys its permission cache by the plugin path exactly as config.kdl's
# file: location expands it, so the key is <prefix>/share/zellij/plugins/<name>.
# A plugin already in the cache gets only its missing scopes added; scopes
# approved by hand stay. Grants for other plugins are never touched.
set -eu

plugin=${1:?usage: zellij-seed-permissions.sh <plugin.wasm> <scope>...}
shift
prefix=${DFUTIL_PREFIX:-$HOME/.local}
file=${XDG_CACHE_HOME:-$HOME/.cache}/zellij/permissions.kdl
key="\"${prefix}/share/zellij/plugins/${plugin}\" {"

mkdir -p "$(dirname "$file")"
touch "$file"

if grep -qxF "$key" "$file"; then
  tmp="${file}.tmp"
  rc=0
  # awk exits 10 when it added a scope.
  awk -v key="$key" -v perms="$*" '
    BEGIN { n = split(perms, want, " ") }
    $0 == key { inblk = 1; print; next }
    inblk && /^}/ {
      for (i = 1; i <= n; i++) if (!(want[i] in have)) { print "    " want[i]; added = 1 }
      inblk = 0; print; next
    }
    inblk { have[$1] = 1; print; next }
    { print }
    END { if (added) exit 10 }
  ' "$file" >"$tmp" || rc=$?
  if [ "$rc" = 10 ]; then
    mv "$tmp" "$file"
    echo "added new zellij permission scopes for ${plugin}"
  else
    rm -f "$tmp"
    [ "$rc" = 0 ] || { echo "could not update zellij permissions for ${plugin} (awk exit ${rc})" >&2; exit 1; }
  fi
  exit 0
fi

{
  echo "$key"
  for scope in "$@"; do
    echo "    ${scope}"
  done
  echo "}"
} >>"$file"
echo "pre-approved zellij permissions for ${plugin}"
