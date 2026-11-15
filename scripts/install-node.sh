#!/bin/sh
# Install the latest Node.js LTS from nodejs.org into $DFUTIL_TOOL_DIR.
#
# Runs as a dfutil script tool. nodejs/node publishes GitHub releases with no
# binary assets, so the github kind cannot install it. dfutil links
# node, npm, and npx from the tool dir into the bin dir (see `bins`).
set -eu

case "$(uname -m)" in
  x86_64) arch=x64 ;;
  aarch64 | arm64) arch=arm64 ;;
  *) echo "node: unsupported architecture $(uname -m)" >&2; exit 1 ;;
esac

# index.json lists releases newest first; "lts" is false or a codename.
version=$(curl -fsSL --connect-timeout 15 --retry 2 https://nodejs.org/dist/index.json |
  tr '{' '\n' | grep '"lts":"' | head -1 |
  sed 's/.*"version":"\([^"]*\)".*/\1/')
[ -n "$version" ] || { echo "node: could not find the latest LTS version" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsSL --connect-timeout 30 --max-time 600 --retry 2 \
  "https://nodejs.org/dist/${version}/node-${version}-linux-${arch}.tar.xz" -o "$tmp/node.tar.xz"
mkdir "$tmp/node"
tar -xJf "$tmp/node.tar.xz" -C "$tmp/node" --strip-components=1

rm -rf "${DFUTIL_TOOL_DIR:?}"
mkdir -p "$(dirname "$DFUTIL_TOOL_DIR")"
mv "$tmp/node" "$DFUTIL_TOOL_DIR"
