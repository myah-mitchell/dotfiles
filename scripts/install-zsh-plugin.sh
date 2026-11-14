#!/bin/sh
# Install a zsh plugin from the source tarball at a pinned git tag.
#
# Usage: install-zsh-plugin.sh <name> <owner/repo> <tag>
# Runs as a dfutil script tool. These repos publish tags but no GitHub
# Releases, so dfutil's github kind cannot see them.
#
# The plugin lands in $DFUTIL_TOOL_DIR/<name> and is linked at
# <prefix>/share/zsh/plugins/<name>, which is where .zshrc sources it from.
set -eu

name=${1:?usage: install-zsh-plugin.sh <name> <owner/repo> <tag>}
repo=${2:?missing repo}
tag=${3:?missing tag}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

curl -fsSL --connect-timeout 30 --max-time 120 --retry 2 \
  "https://github.com/${repo}/archive/refs/tags/${tag}.tar.gz" -o "$tmp/src.tar.gz"
mkdir "$tmp/src"
tar -xzf "$tmp/src.tar.gz" -C "$tmp/src" --strip-components=1

rm -rf "${DFUTIL_TOOL_DIR:?}/${name}"
mkdir -p "$DFUTIL_TOOL_DIR" "$DFUTIL_PREFIX/share/zsh/plugins"
mv "$tmp/src" "$DFUTIL_TOOL_DIR/$name"
ln -sfn "$DFUTIL_TOOL_DIR/$name" "$DFUTIL_PREFIX/share/zsh/plugins/$name"
