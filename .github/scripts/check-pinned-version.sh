#!/usr/bin/env bash
# Checks one pinned dependency (a Zellij plugin release tag, or an npm-pinned
# CLI) against upstream and, if it's behind, rewrites install.sh (and for
# ccstatusline, the mirrored settings.json) in place. Driven entirely by env
# vars set per matrix entry in check-pinned-versions.yml, which lists every
# tracked name and kind.
#
# Values fetched from upstream (release tags, npm versions) are treated as
# untrusted and passed to Perl via %ENV rather than interpolated into -e
# source, so a crafted tag/version string can't inject Perl code.
#
# Writes VERSION_CHANGED/OLD_VERSION/NEW_VERSION/REVIEW_NOTE to $GITHUB_ENV so
# the calling workflow can decide whether to open a PR and what to put in it.
set -euo pipefail

: "${NAME:?}" "${KIND:?}"
INSTALL_SH="install.sh"

api_curl() {
  curl -sf --connect-timeout 15 --retry 3 --retry-delay 2 \
    ${GITHUB_TOKEN:+-H "Authorization: Bearer ${GITHUB_TOKEN}"} "$@"
}

case "$KIND" in
  github-release)
    : "${REPO:?}"
    dest="${NAME}.wasm"

    old_version=$(DEST_ENV="$dest" REPO_ENV="$REPO" perl -ne '
      my ($dest, $repo) = ($ENV{DEST_ENV}, $ENV{REPO_ENV});
      print $1 if /\Q$dest|$repo|\E([^"]+)"/;
    ' "$INSTALL_SH")

    new_version=$(api_curl "https://api.github.com/repos/${REPO}/releases/latest" \
      | grep -oP '"tag_name":\s*"\K[^"]+' | head -1)
    if [[ -z "$new_version" ]]; then
      echo "Could not fetch latest release for ${REPO}" >&2
      exit 1
    fi

    if [[ "$old_version" != "$new_version" ]]; then
      DEST_ENV="$dest" REPO_ENV="$REPO" OLD_ENV="$old_version" NEW_ENV="$new_version" \
        perl -0777 -pi -e '
          my ($dest, $repo, $old, $new) = ($ENV{DEST_ENV}, $ENV{REPO_ENV}, $ENV{OLD_ENV}, $ENV{NEW_ENV});
          s/\Q$dest|$repo|$old\E/$dest|$repo|$new/;
        ' "$INSTALL_SH"
    fi

    review_note="Zellij plugin release. Re-check the plugin's request_permission() call against ZELLIJ_PLUGIN_PERMISSIONS in install.sh. If the new release requests new scopes, that array needs updating too."
    ;;

  npm)
    : "${PACKAGE:?}"

    # The pin is a top-level <PACKAGE>_PINNED_VERSION="..." assignment,
    # shared with install.sh's own --check-pins/--upgrade.
    pin_var="$(tr 'a-z-' 'A-Z_' <<< "$PACKAGE")_PINNED_VERSION"

    old_version=$(VAR_ENV="$pin_var" perl -ne '
      my $var = $ENV{VAR_ENV};
      print $1 if /^\Q$var\E="([^"]+)"/;
    ' "$INSTALL_SH")

    new_version=$(api_curl "https://registry.npmjs.org/${PACKAGE}/latest" | jq -r '.version')
    if [[ -z "$new_version" || "$new_version" == "null" ]]; then
      echo "Could not fetch latest npm version for ${PACKAGE}" >&2
      exit 1
    fi

    if [[ "$old_version" != "$new_version" ]]; then
      VAR_ENV="$pin_var" NEW_ENV="$new_version" perl -pi -e '
        my ($var, $new) = ($ENV{VAR_ENV}, $ENV{NEW_ENV});
        s/^(\Q$var\E=")[^"]+(")/$1$new$2/;
      ' "$INSTALL_SH"
    fi

    review_note="npm-pinned CLI. See the comment above install_${PACKAGE}() in install.sh for what to manually re-verify before merging."

    if [[ "$PACKAGE" == "ccstatusline" && "$old_version" != "$new_version" ]]; then
      settings_json="ccstatusline/.config/ccstatusline/settings.json"
      jq --arg v "$new_version" '.installation.installedVersion = $v' "$settings_json" > "${settings_json}.tmp"
      mv "${settings_json}.tmp" "$settings_json"
      review_note="${review_note} Also updated the mirrored installation.installedVersion in ${settings_json} to match."
    fi
    ;;

  *)
    echo "Unknown KIND: ${KIND}" >&2
    exit 1
    ;;
esac

# An empty old_version means the matrix entry no longer matches install.sh
# (a renamed plugin or a changed repo). Fail instead of reporting a bogus bump.
if [[ -z "$old_version" ]]; then
  echo "No pin for ${NAME} found in ${INSTALL_SH}; update the workflow matrix to match" >&2
  exit 1
fi

echo "${NAME}: ${old_version} -> ${new_version}"

{
  echo "OLD_VERSION=${old_version}"
  echo "NEW_VERSION=${new_version}"
  echo "REVIEW_NOTE=${review_note}"
  echo "VERSION_CHANGED=$([[ "$old_version" != "$new_version" ]] && echo true || echo false)"
} >> "$GITHUB_ENV"
