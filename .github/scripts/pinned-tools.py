#!/usr/bin/env python3
"""Lists the exact pins in dfutil.toml that the weekly bump check covers.

With no arguments, prints a GitHub Actions matrix ({"include": [...]}) with one
entry per pinned tool. With a tool name, prints that tool's entry as JSON,
including its current version, for check-pinned-version.sh.

A tool is covered when its pin names one exact release:
  - a github tool with `pin = "tag:<tag>"` or an exact `X.Y.Z` / `vX.Y.Z` pin
  - an npm tool with an exact `X.Y.Z` pin
  - a zsh plugin: a script tool whose install runs
    `scripts/install-zsh-plugin.sh <name> <owner/repo> <tag>`

Floating pins (`latest`, `15`, `15.1`, a `*` prefix) already track upstream
at install time, so they're left out.
"""

import json
import re
import shlex
import sys
import tomllib

CONFIG = "dfutil.toml"
EXACT_VERSION = re.compile(r"^v?\d+\.\d+\.\d+$")


def entry(name, tool):
    kind = tool.get("kind") or ("github" if "repo" in tool else None)
    pin = tool.get("pin", "")
    if kind == "github":
        if pin.startswith("tag:"):
            version = pin[len("tag:"):]
        elif EXACT_VERSION.match(pin):
            version = pin
        else:
            return None
        links = tool.get("links", {})
        role = (
            "zellij-plugin"
            if any(path.startswith("share/zellij/plugins/") for path in links)
            else "tool"
        )
        return {"name": name, "kind": "github-release", "role": role,
                "repo": tool["repo"], "version": version}
    if kind == "npm":
        if not EXACT_VERSION.match(pin):
            return None
        return {"name": name, "kind": "npm", "role": "npm",
                "package": tool.get("package", name), "version": pin}
    if kind == "script":
        words = shlex.split(tool.get("install", ""))
        if len(words) == 5 and words[1] == "scripts/install-zsh-plugin.sh":
            _, _, plugin, repo, tag = words
            return {"name": name, "kind": "github-tag", "role": "zsh-plugin",
                    "repo": repo, "version": tag}
    return None


def main():
    with open(CONFIG, "rb") as handle:
        tools = tomllib.load(handle).get("tools", {})
    entries = {}
    for name, tool in tools.items():
        found = entry(name, tool)
        if found:
            entries[name] = found
    if len(sys.argv) > 1:
        name = sys.argv[1]
        if name not in entries:
            sys.exit(f"{CONFIG}: no exact pin for tool `{name}`")
        print(json.dumps(entries[name]))
    else:
        # The matrix only needs the name; the check reads the rest itself.
        print(json.dumps({"include": [{"name": n} for n in entries]}))


if __name__ == "__main__":
    main()
