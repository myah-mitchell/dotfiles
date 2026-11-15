#!/usr/bin/env bash
# Retrieve the resident SSH keys already stored on a YubiKey (or any FIDO2
# authenticator) into ~/.ssh with `ssh-keygen -K`.
#
# Usage: scripts/yubikey-ssh-keys.sh
#
# Retrieve only: it doesn't provision a key. If the YubiKey has no resident
# key yet, create one first with `ssh-keygen -t ed25519-sk -O resident`.
#
# `ssh-keygen -K` names its output files from what's stored on the device, so
# it runs inside ~/.ssh rather than being told where to write. It needs an
# OpenSSH 8.2+ client with security-key support, which loads libfido2 at
# runtime. Detecting that up front is fragile (package names, linked-in versus
# dlopen support, and provider paths all vary by distro), so this runs the
# real operation and classifies any failure from its output.
set -uo pipefail

if [[ -t 1 ]]; then
  red=$'\033[0;31m' green=$'\033[0;32m' yellow=$'\033[1;33m' blue=$'\033[0;34m' reset=$'\033[0m'
else
  red='' green='' yellow='' blue='' reset=''
fi
log() { printf '%s[yubikey]%s %s\n' "$blue" "$reset" "$*"; }
ok() { printf '%s[ok]%s %s\n' "$green" "$reset" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$yellow" "$reset" "$*" >&2; }
err() { printf '%s[error]%s %s\n' "$red" "$reset" "$*" >&2; }

if ! command -v ssh-keygen >/dev/null 2>&1; then
  err "ssh-keygen not found. Install an OpenSSH client first."
  exit 1
fi

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

log "Insert the YubiKey if it isn't already, then touch it when it blinks. It may also ask for its PIN."

before=$(find "$HOME/.ssh" -maxdepth 1 -type f -name '*_sk*' 2>/dev/null | sort)
output=$(mktemp)
trap 'rm -f "$output"' EXIT

# Retrieval is interactive (a touch, maybe a PIN), so the output streams
# straight to the terminal; tee keeps a copy for classifying a failure.
(cd "$HOME/.ssh" && ssh-keygen -K) 2>&1 | tee "$output"
status=${PIPESTATUS[0]}

if ((status != 0)); then
  # Order matters: an OpenSSH 10.x client with FIDO2 built in prints
  # `Provider "internal" returned failure` for the ordinary "no key plugged
  # in" case, so that's matched before the broad missing-library patterns.
  if grep -qiE "illegal option|unknown option|invalid option" "$output"; then
    err "This ssh-keygen doesn't support -K. It needs OpenSSH 8.2+ built with security-key support:"
    err "  sudo apt install --only-upgrade openssh-client"
  elif grep -qiE "device not found|no fido|no security key|no u2f|no such device|couldn't read" "$output"; then
    err "No FIDO2 authenticator detected. Insert the YubiKey (touch it if it's blinking) and run this again."
  elif grep -qiE "cannot open shared object|failed to dlopen|error while loading shared libraries|libfido2.*not found|provider" "$output"; then
    err "ssh-keygen couldn't load its FIDO2 provider (libfido2). Install it and run this again:"
    err "  sudo apt install libfido2-1"
  else
    err "ssh-keygen -K failed; see its output above."
  fi
  exit 1
fi

after=$(find "$HOME/.ssh" -maxdepth 1 -type f -name '*_sk*' 2>/dev/null | sort)
new_files=$(comm -13 <(echo "$before") <(echo "$after"))

if [[ -z "$new_files" ]]; then
  warn "ssh-keygen -K succeeded, but no new files appeared in ~/.ssh. The YubiKey may have no resident keys yet; provision one with: ssh-keygen -t ed25519-sk -O resident"
  exit 0
fi

while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  if [[ "$file" == *.pub ]]; then
    chmod 644 "$file"
  else
    chmod 600 "$file"
  fi
  ok "Retrieved $(basename "$file")"
done <<<"$new_files"

echo
log "To use it by default, add an IdentityFile line for the private stub above to the Host * block in ~/.ssh/config. The committed config only lists id_ed25519 and id_rsa."
