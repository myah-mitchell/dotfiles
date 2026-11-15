#!/usr/bin/env bash
# Checks one pinned tool from dfutil.toml against upstream and, if it's behind,
# rewrites the pin in dfutil.toml and the matching pin in install.sh, so the
# two can't drift while both are in use. For ccstatusline it also syncs the
# mirrored installedVersion in its settings.json. NAME is the dfutil tool
# name; pinned-tools.py supplies the kind, repo, and current version.
#
# Values fetched from upstream (release tags, npm versions) are treated as
# untrusted: they're checked against a safe character set, and passed to Perl
# via %ENV rather than interpolated into -e source, so a crafted tag/version
# string can't inject Perl code.
#
# Writes VERSION_CHANGED/OLD_VERSION/NEW_VERSION/REVIEW_NOTE/CHANGELOG to $GITHUB_ENV so
# the calling workflow can decide whether to open a PR and what to put in it.
set -euo pipefail

: "${NAME:?}"
CONFIG="dfutil.toml"
INSTALL_SH="install.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

api_curl() {
  curl -sf --connect-timeout 15 --retry 3 --retry-delay 2 \
    ${GITHUB_TOKEN:+-H "Authorization: Bearer ${GITHUB_TOKEN}"} "$@"
}

# Builds the PR's changelog section from the upstream GitHub Releases between
# the old pin (exclusive) and the new one (inclusive), newest first. Tags match
# with or without a leading "v", since npm versions carry no prefix. Releases
# in between are skipped when they're pre-releases or aliases (non-version
# tags). Prints nothing if upstream has no matching release.
#
# Release notes are untrusted, and this repo is public, so the PR body must not
# touch upstream: @mentions become code spans (no notification), and every
# GitHub link and #123 / owner/repo#123 ref goes through redirect.github.com,
# which GitHub doesn't record as a cross-reference on the upstream issue.
release_notes() {
  local repo="$1" old="$2" new="$3" releases notes compare=""
  releases=$(api_curl "https://api.github.com/repos/${repo}/releases?per_page=100") || return 0
  notes=$(jq -r --arg old "$old" --arg new "$new" '
        def idx($v): map(.tag_name == $v or .tag_name == "v\($v)") | index(true);
        [.[] | select(.draft | not)] as $r
        | ($r | idx($new)) as $ni
        | ($r | idx($old)) as $oi
        | if $ni == null then empty else
            $r[$ni:(if $oi != null and $oi > $ni then $oi else $ni + 1 end)]
            | to_entries[]
            | select(.key == 0 or ((.value.prerelease | not) and (.value.tag_name | test("^v?[0-9]"))))
            | "<details\(if .key == 0 then " open" else "" end)><summary><b>\(.value.tag_name)</b></summary>\n\n\(.value.body // "_No release notes._" | gsub("\r"; ""))\n\n</details>\n"
          end' <<< "$releases" 2>/dev/null) || return 0
  [[ -n "$notes" ]] || return 0

  notes=$(REPO_ENV="$repo" perl -pe '
    my $repo = $ENV{REPO_ENV};
    my $r = "https://redirect.github.com";
    s{https?://(?:www\.)?github\.com/}{$r/}g;
    s/(?<![\w`\/.])@([A-Za-z0-9](?:[A-Za-z0-9-]{0,38}))\b/`\@$1`/g;
    s{(?<![\w\/.\[-])([\w.-]+/[\w.-]+)#(\d+)\b}{[$1#$2]($r/$1/issues/$2)}g;
    s{(?<![\w&/#\[-])#(\d+)\b}{[#$1]($r/$repo/issues/$1)}g;
  ' <<< "$notes")

  # GitHub caps a PR body at 65536 characters; leave room for the rest.
  if (( ${#notes} > 50000 )); then
    notes="${notes:0:50000}"$'\n\n'"_Truncated._"
  fi

  echo "## Upstream changes"
  echo
  # Compare by the real tag names, which may carry a "v" the pins don't.
  local old_tag new_tag
  old_tag=$(jq -r --arg v "$old" 'map(.tag_name) | map(select(. == $v or . == "v\($v)")) | .[0] // empty' <<< "$releases")
  new_tag=$(jq -r --arg v "$new" 'map(.tag_name) | map(select(. == $v or . == "v\($v)")) | .[0] // empty' <<< "$releases")
  if [[ -n "$old_tag" && -n "$new_tag" ]]; then
    compare="[Compare ${old_tag}...${new_tag}](https://github.com/${repo}/compare/${old_tag}...${new_tag}), "
  fi
  echo "${compare}[all releases](https://github.com/${repo}/releases)"
  echo
  printf '%s\n' "$notes"
}

pin=$(python3 "${SCRIPT_DIR}/pinned-tools.py" "$NAME")
field() { jq -r --arg k "$1" '.[$k] // empty' <<< "$pin"; }
KIND=$(field kind)
ROLE=$(field role)
REPO=$(field repo)
PACKAGE=$(field package)
old_version=$(field version)
notes_repo="$REPO"

# Tags-only repos: the tags API has no "latest" the way /releases/latest
# does, so take the highest clean vX.Y.Z-style tag, falling back to the
# highest tag of any shape. `sort -V` alone ranks a suffixed pre-release tag
# such as 0.8.0-alpha1-pre-redrawhook above the plain 0.8.0 it predates.
latest_github_tag() {
  local tags clean
  tags=$(api_curl "https://api.github.com/repos/$1/tags?per_page=100" | jq -r '.[].name') || return 1
  clean=$(grep -E '^v?[0-9]+(\.[0-9]+){1,2}$' <<< "$tags" | sort -V | tail -1) || true
  if [[ -n "$clean" ]]; then
    echo "$clean"
  else
    sort -V <<< "$tags" | tail -1
  fi
}

case "$KIND" in
  github-release)
    new_version=$(api_curl "https://api.github.com/repos/${REPO}/releases/latest" | jq -r '.tag_name // empty')
    ;;
  github-tag)
    new_version=$(latest_github_tag "$REPO")
    # Tags have no release notes to quote.
    notes_repo=""
    ;;
  npm)
    npm_meta=$(api_curl "https://registry.npmjs.org/${PACKAGE}/latest")
    new_version=$(jq -r '.version // empty' <<< "$npm_meta")
    # Release notes come from the package's GitHub repo, when it has one.
    notes_repo=$(jq -r '.repository.url // .repository // empty' <<< "$npm_meta" \
      | sed -nE 's#^(git\+)?(https?|git|ssh)://(git@)?github\.com[/:]([^/]+/[^/.]+)(\.git)?/?$#\4#p')
    ;;
  *)
    echo "Unknown kind for ${NAME}: ${KIND}" >&2
    exit 1
    ;;
esac

if [[ -z "$new_version" ]]; then
  echo "Could not fetch the latest version of ${NAME}" >&2
  exit 1
fi
if [[ ! "$new_version" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Refusing ${NAME}'s upstream version '${new_version}': unexpected characters" >&2
  exit 1
fi

install_sh_note=""
if [[ "$old_version" != "$new_version" ]]; then
  # dfutil.toml: only the pin, install, and version lines of [tools.<NAME>].
  # A version is replaced only as a whole token, so 1.1 can't match in 1.11.
  NAME_ENV="$NAME" OLD_ENV="$old_version" NEW_ENV="$new_version" perl -pi -e '
    BEGIN { ($name, $old, $new) = @ENV{qw(NAME_ENV OLD_ENV NEW_ENV)} }
    $in = ($1 eq "tools.$name") if /^\s*\[([^\]]+)\]/;
    s/(?<![A-Za-z0-9._-])\Q$old\E(?![A-Za-z0-9._-])/$new/g
      if $in && /^\s*(?:pin|install|version)\s*=/;
  ' "$CONFIG"

  # install.sh keeps its own copy of the pin until the fleet hosts move to
  # dfutil. A github pin is a quoted "<dest>|<repo>|<tag>" row in
  # ZELLIJ_PLUGINS, ZSH_PLUGINS, or TOOL_PINS, where a Zellij plugin's dest
  # carries .wasm. The opening quote keeps it from matching inside a
  # CORE_TOOLS row. A * prefix row is left alone. An npm pin is
  # <PACKAGE>_PINNED_VERSION="...".
  install_old=$(NAME_ENV="$NAME" REPO_ENV="$REPO" PACKAGE_ENV="$PACKAGE" perl -ne '
    my ($name, $repo, $package) = @ENV{qw(NAME_ENV REPO_ENV PACKAGE_ENV)};
    if ($package ne "") {
      (my $var = uc $package) =~ tr/-/_/;
      print $1 if /^\Q${var}\E_PINNED_VERSION="([^"]+)"/;
    } else {
      print $2 if /"\Q$name\E(\.wasm)?\|\Q$repo\E\|([^"*]+)"/;
    }
  ' "$INSTALL_SH")
  if [[ -n "$install_old" ]]; then
    NAME_ENV="$NAME" REPO_ENV="$REPO" PACKAGE_ENV="$PACKAGE" NEW_ENV="$new_version" perl -pi -e '
      BEGIN { ($name, $repo, $package, $new) = @ENV{qw(NAME_ENV REPO_ENV PACKAGE_ENV NEW_ENV)} }
      if ($package ne "") {
        (my $var = uc $package) =~ tr/-/_/;
        s/^(\Q${var}\E_PINNED_VERSION=")[^"]+(")/$1$new$2/;
      } else {
        s/("\Q$name\E(?:\.wasm)?\|\Q$repo\E\|)[^"*]+(")/$1$new$2/;
      }
    ' "$INSTALL_SH"
    install_sh_note=" Also bumped the matching pin in install.sh (was ${install_old})."
  else
    install_sh_note=" install.sh has no matching exact pin, so only dfutil.toml changed."
  fi
fi

case "$ROLE" in
  zellij-plugin)
    review_note="Zellij plugin release. Re-check the plugin's request_permission() call against the scope list in this tool's post_install in dfutil.toml, and against ZELLIJ_PLUGIN_PERMISSIONS in install.sh. If the new release requests new scopes, update both."
    ;;
  tool)
    review_note="Pinned release. Check the new release still publishes an asset matching each of the tool's assets globs in dfutil.toml and its CORE_TOOLS/CLI_TOOLS rows in install.sh."
    ;;
  zsh-plugin)
    review_note="zsh plugin tag, picked as the highest version-sorted tag, not a published release. Check it really is the newest release before merging: the plugin loads in every new shell."
    ;;
  npm)
    review_note="npm-pinned CLI. See the comment on this tool in dfutil.toml and above install_${PACKAGE}() in install.sh for what to re-verify before merging."
    ;;
esac
review_note="${review_note}${install_sh_note}"

if [[ "$PACKAGE" == "ccstatusline" && "$old_version" != "$new_version" ]]; then
  settings_json="ccstatusline/.config/ccstatusline/settings.json"
  jq --arg v "$new_version" '.installation.installedVersion = $v' "$settings_json" > "${settings_json}.tmp"
  mv "${settings_json}.tmp" "$settings_json"
  review_note="${review_note} Also updated the mirrored installation.installedVersion in ${settings_json} to match."
fi

echo "${NAME}: ${old_version} -> ${new_version}"

changelog=""
if [[ "$old_version" != "$new_version" && -n "${notes_repo:-}" ]]; then
  changelog=$(release_notes "$notes_repo" "$old_version" "$new_version")
fi

{
  echo "OLD_VERSION=${old_version}"
  echo "NEW_VERSION=${new_version}"
  echo "REVIEW_NOTE=${review_note}"
  echo "VERSION_CHANGED=$([[ "$old_version" != "$new_version" ]] && echo true || echo false)"
  # Multiline value; a random delimiter so upstream text can't end it early.
  delim="CHANGELOG_$(openssl rand -hex 16)"
  echo "CHANGELOG<<${delim}"
  printf '%s\n' "$changelog"
  echo "$delim"
} >> "$GITHUB_ENV"
