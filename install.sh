#!/usr/bin/env bash
# install.sh — bootstrap dotfiles, download binaries, symlink configs
# Usage: ./install.sh [--update] [--link] [--copy] [--remove] [--no-windows] [--cargo]
#
# --update      Force re-download/rebuild all tools even if already at latest version
# --link        Skip binary downloads, only re-link configs (fast config-only updates)
# --copy        Copy configs instead of symlinking (useful on NTFS or shared servers)
# --remove      Remove all deployed symlinks from $HOME and exit (does not touch binaries)
# --no-windows  Skip Windows/Alacritty PowerShell setup (WSL2 only)
# --cargo       Build all Rust tools from source via cargo (slow; Go/C tools still download)

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log()  { echo -e "${CYAN}[dotfiles]${RESET} $*"; }
ok()   { echo -e "${GREEN}[✓]${RESET} $*"; }
warn() { echo -e "${YELLOW}[!]${RESET} $*"; }
err()  { echo -e "${RED}[✗]${RESET} $*" >&2; }

# ── Args ──────────────────────────────────────────────────────────────────────
FORCE_UPDATE=false; LINK_ONLY=false; USE_COPY=false; DO_REMOVE=false; NO_WINDOWS=false; USE_CARGO=false
for arg in "$@"; do
  case $arg in
    --update)     FORCE_UPDATE=true ;;
    --link)       LINK_ONLY=true ;;
    --copy)       USE_COPY=true ;;
    --remove)     DO_REMOVE=true ;;
    --no-windows) NO_WINDOWS=true ;;
    --cargo)      USE_CARGO=true ;;
    *) err "Unknown flag: $arg"; exit 1 ;;
  esac
done

# ── Paths ─────────────────────────────────────────────────────────────────────
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$DOTFILES/bin/.local/bin"
SHARE_DIR="$DOTFILES/bin/.local/share"
LOCAL_BIN="$HOME/.local/bin"
VERSIONS_FILE="$LOCAL_BIN/.versions"
LOCAL_SHARE="$HOME/.local/share"

# ── Platform detection ────────────────────────────────────────────────────────
# Refuse to run in Git Bash / MSYS — symlink semantics break on Windows
if [[ "${OSTYPE:-}" == "msys" || "${OSTYPE:-}" == "cygwin" || "$(uname -s)" == MINGW* ]]; then
  err "Run this script inside WSL, not Git Bash / MSYS."
  err "  wsl -e bash ~/GitHub/dotfiles/install.sh"
  exit 1
fi

OS="linux"
ARCH="x86_64"
[[ "$(uname -s)" == "Darwin" ]] && OS="darwin"
[[ "$(uname -m)" == "aarch64" || "$(uname -m)" == "arm64" ]] && ARCH="aarch64"

IS_WSL=false
if grep -qi microsoft /proc/version 2>/dev/null; then
  IS_WSL=true
fi

log "Platform: ${OS}/${ARCH} | WSL: ${IS_WSL} | Dotfiles: ${DOTFILES}"

# ── GitHub auth ───────────────────────────────────────────────────────────────
# Set GITHUB_TOKEN in your environment to raise the API limit from 60 to 5,000
# requests/hour. Without it, a fresh install with 25+ tools can hit the limit.
GITHUB_AUTH=()
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  GITHUB_AUTH=(-H "Authorization: Bearer $GITHUB_TOKEN")
  log "GitHub token found — using authenticated API (5,000 req/hr limit)"
else
  warn "No GITHUB_TOKEN set — unauthenticated API limit is 60 req/hr. Set it to avoid rate limiting on fresh installs."
fi

# ── Prerequisites ─────────────────────────────────────────────────────────────
for cmd in curl tar unzip; do
  if ! command -v "$cmd" &>/dev/null; then
    err "Required tool not found: $cmd — please install it first."
    exit 1
  fi
done

# ── Git (Linux/WSL) ───────────────────────────────────────────────────────────
# Ubuntu 22.04 ships git 2.34; zdiff3 merge style requires 2.35+.
# The git-core PPA provides the latest stable git on Ubuntu/Debian.
if [[ "$OS" == "linux" ]] && command -v apt-get &>/dev/null; then
  git_ver=$(git --version 2>/dev/null | grep -oP '\d+\.\d+' | head -1)
  git_major=${git_ver%%.*}
  git_minor=${git_ver##*.}
  if (( git_major < 2 || (git_major == 2 && git_minor < 35) )); then
    log "Upgrading git to 2.35+ (required for zdiff3 merge style)..."
    if sudo add-apt-repository -y ppa:git-core/ppa 2>/dev/null \
      && sudo apt-get update -qq 2>/dev/null \
      && sudo apt-get install -y git 2>/dev/null; then
      ok "git upgraded to $(git --version)"
    else
      warn "git upgrade failed — zdiff3 merge style may not work (non-fatal)"
    fi
  fi
fi

# ── Locale (Linux/WSL) ───────────────────────────────────────────────────────
# WSL2 distros often ship without en_US.UTF-8 generated, causing bash to warn
# "cannot change locale (en_US.UTF-8)" on every subprocess spawn (e.g. from nvim).
if [[ "$OS" == "linux" ]] && command -v locale-gen &>/dev/null; then
  if ! locale -a 2>/dev/null | grep -q "en_US.utf8"; then
    log "Generating en_US.UTF-8 locale..."
    if sudo locale-gen en_US.UTF-8 2>/dev/null \
      && sudo update-locale LANG=en_US.UTF-8 2>/dev/null; then
      ok "Locale en_US.UTF-8 generated"
    else
      warn "locale-gen failed — LC_ALL warnings from subprocesses may appear (non-fatal)"
    fi
  fi
fi

# ── Directory setup ───────────────────────────────────────────────────────────
mkdir -p "$BIN_DIR" "$SHARE_DIR" "$LOCAL_BIN" "$LOCAL_SHARE" \
         "$HOME/.ssh/sockets" "$HOME/.cache/starship" "$HOME/.cache/carapace" \
         "$HOME/.local/share/atuin" "$HOME/.config/nushell"
chmod 700 "$HOME/.ssh"
touch "$VERSIONS_FILE"
# Nushell sources these at parse time — files must always exist even if empty
touch "$HOME/.config/nushell/secrets.nu"
touch "$HOME/.cache/carapace/init.nu"

# ── Version tracking ──────────────────────────────────────────────────────────
get_installed_version() { grep "^$1=" "$VERSIONS_FILE" 2>/dev/null | cut -d= -f2 || echo ""; }
set_installed_version() {
  local key="$1" ver="$2"
  if grep -q "^${key}=" "$VERSIONS_FILE" 2>/dev/null; then
    sed -i "s|^${key}=.*|${key}=${ver}|" "$VERSIONS_FILE"
  else
    echo "${key}=${ver}" >> "$VERSIONS_FILE"
  fi
}

# ── GitHub release downloader ─────────────────────────────────────────────────
# Usage: download_release REPO ASSET_GLOB DEST_BIN [BINARY_IN_ARCHIVE]
# ASSET_GLOB: shell glob matching the archive filename, e.g. "bat-*-x86_64*linux*musl*.tar.gz"
# DEST_BIN:   filename to create in BIN_DIR
# BINARY_IN_ARCHIVE: path inside archive to the binary (default: same as DEST_BIN)
download_release() {
  local repo="$1" glob="$2" dest="$3" bin_in_archive="${4:-$3}"
  local key="${dest}"
  local installed
  installed=$(get_installed_version "$key")

  log "Checking ${dest}..."

  # Skip the API call entirely when already installed and not forcing update.
  # With 25+ tools and 60 unauthenticated requests/hour, making an API call for
  # every tool on every run burns the rate limit and causes tools past ~tool 10
  # to never record their version in .versions (they get "Could not fetch" and
  # return early, leaving installed="" on the next run → re-download loop).
  if [[ -n "$installed" && "$FORCE_UPDATE" == false ]]; then
    ok "${dest} already at ${installed}"
    return
  fi

  # Single API call — parse both tag_name and asset URLs from one response.
  local api_response
  api_response=$(curl -sf --connect-timeout 15 --retry 3 --retry-delay 2 \
    "${GITHUB_AUTH[@]}" "https://api.github.com/repos/${repo}/releases/latest") || true

  local latest
  latest=$(echo "$api_response" | grep -oP '"tag_name":\s*"\K[^"]+' | head -1) || true
  if [[ -z "$latest" ]]; then
    warn "Could not fetch latest version for ${repo} — skipping."
    return
  fi

  if [[ "$installed" == "$latest" && "$FORCE_UPDATE" == false ]]; then
    ok "${dest} already at ${latest}"
    return
  fi

  log "Downloading ${dest} ${latest}..."

  # Convert shell glob wildcards (*) to grep extended-regex (.*) for proper matching
  local regex="${glob//\*/.*}"

  # Find the matching asset URL from the cached API response
  local asset_url
  asset_url=$(echo "$api_response" \
    | grep '"browser_download_url"' \
    | grep -v '\.sha256\|\.sha512\|\.asc\|\.sig\|checksums\|\.deb\|\.rpm\|\.msi\|\.dmg\|\.pkg\|-apple-darwin\|windows\|\.exe\|android' \
    | grep -iE "$regex" \
    | head -1 \
    | cut -d'"' -f4) || true

  if [[ -z "$asset_url" ]]; then
    # Fallback: /releases/latest may have no assets on some repos. Try the
    # releases list and take the newest release that has a matching asset.
    local releases_response
    releases_response=$(curl -sf --connect-timeout 15 --retry 3 --retry-delay 2 \
      "${GITHUB_AUTH[@]}" "https://api.github.com/repos/${repo}/releases?per_page=5") || true
    asset_url=$(echo "$releases_response" \
      | grep '"browser_download_url"' \
      | grep -v '\.sha256\|\.sha512\|\.asc\|\.sig\|checksums\|\.deb\|\.rpm\|\.msi\|\.dmg\|\.pkg\|-apple-darwin\|windows\|\.exe\|android' \
      | grep -iE "$regex" \
      | head -1 \
      | cut -d'"' -f4) || true
    if [[ -n "$asset_url" ]]; then
      # Extract version from the URL for tracking
      latest=$(echo "$releases_response" | grep -oP '"tag_name":\s*"\K[^"]+' | head -1) || true
    fi
  fi

  if [[ -z "$asset_url" ]]; then
    warn "No matching asset found for ${dest} (pattern: ${glob}) — skipping."
    return
  fi

  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf '$tmpdir'" RETURN

  local archive="${tmpdir}/archive"
  if ! curl -fL --connect-timeout 30 --max-time 600 --retry 2 "$asset_url" -o "$archive"; then
    warn "Download failed for ${dest} — skipping."
    return
  fi

  # Detect archive type and extract
  local extracted_binary
  if [[ "$asset_url" == *.tar.gz || "$asset_url" == *.tgz ]]; then
    tar -xzf "$archive" -C "$tmpdir"
    extracted_binary=$(find "$tmpdir" -name "$bin_in_archive" -not -name "*.gz" | head -1)
  elif [[ "$asset_url" == *.tar.xz ]]; then
    tar -xJf "$archive" -C "$tmpdir"
    extracted_binary=$(find "$tmpdir" -name "$bin_in_archive" | head -1)
  elif [[ "$asset_url" == *.zip ]]; then
    unzip -q "$archive" -d "$tmpdir"
    extracted_binary=$(find "$tmpdir" -name "$bin_in_archive" | head -1)
  else
    # Plain binary
    extracted_binary="$archive"
  fi

  if [[ -z "$extracted_binary" || ! -f "$extracted_binary" ]]; then
    warn "Could not find '${bin_in_archive}' in archive for ${dest} — skipping."
    return
  fi

  install -m 755 "$extracted_binary" "$BIN_DIR/$dest"
  set_installed_version "$key" "$latest"
  ok "${dest} installed at ${latest}"
}

# ── Cargo installer ───────────────────────────────────────────────────────────
# Usage: cargo_install CRATE DEST_BIN
# Installs to dotfiles bin dir via cargo (symlinked to ~/.local/bin by link_package).
# Checks crates.io for the latest version to avoid unnecessary recompiles.
cargo_install() {
  local crate="$1" dest="$2"
  local cargo_bin="$HOME/.cargo/bin/cargo"
  log "Checking ${dest} (cargo)..."
  if [[ ! -x "$cargo_bin" ]]; then
    warn "${dest}: cargo not available — skipping"
    return
  fi
  local latest
  latest=$(curl -sf --connect-timeout 15 \
    -H "User-Agent: dotfiles-install/1.0" \
    "https://crates.io/api/v1/crates/${crate}" \
    | grep -oP '"newest_version"\s*:\s*"\K[^"]+' | head -1) || true
  if [[ -z "$latest" ]]; then
    warn "Could not fetch latest version for ${crate} — skipping"
    return
  fi
  local installed
  installed=$(get_installed_version "$dest")
  if [[ -z "$installed" ]]; then
    installed=$("$cargo_bin" install --list --root "$DOTFILES/bin/.local" 2>/dev/null \
      | grep -oP "^${crate} v\K[0-9][^:]+")
    [[ -n "$installed" ]] && set_installed_version "$dest" "$installed"
  fi
  if [[ "$installed" == "$latest" && "$FORCE_UPDATE" == false ]]; then
    ok "${dest} already at ${latest}"
    return
  fi
  log "Installing ${dest} ${latest} via cargo (compiling from source)..."
  local -a flags=(--root "$DOTFILES/bin/.local" --force)
  # Try --locked first: if the crate published a Cargo.lock it pins transitive
  # deps (e.g. interprocess 1.x) that may otherwise resolve to a breaking version.
  local install_ok=false
  if "$cargo_bin" install "$crate" --locked "${flags[@]}" 2>&1; then
    install_ok=true
  else
    log "Retrying ${dest} without --locked..."
    if "$cargo_bin" install "$crate" "${flags[@]}" 2>&1; then
      install_ok=true
    fi
  fi
  if [[ "$install_ok" == true ]]; then
    set_installed_version "$dest" "$latest"
    ok "${dest} installed at ${latest}"
  else
    warn "cargo install ${crate} failed — skipping (plugin may not be compatible with your nu version)"
  fi
}

# ── Generic tool installer ────────────────────────────────────────────────────
# Row format (pipe-separated):
#   dest | crate | repo | os | arch | glob | bin
# os:   linux | darwin
# arch: x86_64 | aarch64 | * (matches any arch for that os)
# crate: cargo crate name, or - if not available via cargo
# bin:  binary name inside archive; defaults to dest when -
# One row per supported platform variant.
declare -A _cargo_done=()
install_tool() {
  local dest crate repo os arch glob bin
  IFS='|' read -r dest crate repo os arch glob bin <<< "$1"
  [[ "$bin" == "-" ]] && bin="$dest"

  if [[ "$USE_CARGO" == true && "$crate" != "-" ]]; then
    if [[ -z "${_cargo_done[$dest]+x}" ]]; then
      cargo_install "$crate" "$dest"
      _cargo_done[$dest]=1
    fi
    return
  fi

  if [[ "$OS" == "$os" ]] && [[ "$arch" == "*" || "$ARCH" == "$arch" ]]; then
    download_release "$repo" "$glob" "$dest" "$bin"
  fi
}

# ── Binary downloads ──────────────────────────────────────────────────────────
if [[ "$LINK_ONLY" == false ]]; then

  if [[ "$USE_CARGO" == true ]]; then
    log "=== Rust toolchain ==="
    CARGO_BIN="$HOME/.cargo/bin/cargo"
    if [[ -x "$CARGO_BIN" ]]; then
      ok "cargo already installed: $("$CARGO_BIN" --version)"
    else
      log "Installing Rust via rustup..."
      curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --no-modify-path --quiet
      ok "Rust installed: $("$CARGO_BIN" --version)"
    fi
    export PATH="$HOME/.cargo/bin:$PATH"

    # cargo needs a C linker (cc/gcc) even for pure-Rust crates.
    if ! command -v cc &>/dev/null && ! command -v gcc &>/dev/null; then
      log "C linker not found — installing build-essential..."
      if command -v apt-get &>/dev/null; then
        sudo apt-get install -y build-essential \
          && ok "build-essential installed" \
          || { err "Could not install build-essential — cargo builds will fail."; }
      elif command -v brew &>/dev/null; then
        brew install gcc && ok "gcc installed"
      else
        err "No C linker found and no known package manager to install one."
        err "Install gcc/build-essential manually, then re-run with --cargo."
        exit 1
      fi
    fi

    warn "Cargo mode: all Rust tools will compile from source — this may take a while."
  fi

  log "=== Core shell stack ==="

  # dest | crate | repo | os | arch | glob | bin
  CORE_TOOLS=(
    "nu|nu|nushell/nushell|linux|x86_64|nu-*-x86_64*linux*musl*.tar.gz|-"
    "nu|nu|nushell/nushell|linux|aarch64|nu-*-aarch64*linux*musl*.tar.gz|-"
    "nu|nu|nushell/nushell|darwin|x86_64|nu-*-x86_64*apple*darwin*.tar.gz|-"
    "nu|nu|nushell/nushell|darwin|aarch64|nu-*-aarch64*apple*darwin*.tar.gz|-"

    "starship|starship|starship/starship|linux|x86_64|starship-x86_64-unknown-linux-musl.tar.gz|-"
    "starship|starship|starship/starship|linux|aarch64|starship-aarch64-unknown-linux-musl.tar.gz|-"
    "starship|starship|starship/starship|darwin|*|starship-*-apple-darwin.tar.gz|-"

    "zellij|zellij|zellij-org/zellij|linux|x86_64|zellij-x86_64-unknown-linux-musl.tar.gz|-"
    "zellij|zellij|zellij-org/zellij|linux|aarch64|zellij-aarch64-unknown-linux-musl.tar.gz|-"
    "zellij|zellij|zellij-org/zellij|darwin|*|zellij-*-apple-darwin.tar.gz|-"
  )
  for t in "${CORE_TOOLS[@]}"; do install_tool "$t"; done

  # Neovim — tarball release (includes runtime + bundled treesitter parsers).
  # AppImage was dropped: it omits the runtime directory and requires FUSE
  # which is unavailable in most WSL2 kernels.
  log "Checking nvim..."
  latest=$(curl -sf --connect-timeout 15 --retry 3 --retry-delay 2 \
    "${GITHUB_AUTH[@]}" "https://api.github.com/repos/neovim/neovim/releases/latest" \
    | grep -oP '"tag_name":\s*"\K[^"]+' | head -1) || true
  if [[ -z "$latest" ]]; then
    warn "Could not determine nvim latest version — skipping."
  else
    installed=$(get_installed_version "nvim")
    if [[ "$installed" != "$latest" || "$FORCE_UPDATE" == true || ! -f "$HOME/.local/share/nvim/runtime/syntax/syntax.vim" ]]; then
      log "Downloading nvim ${latest}..."
      tmpdir=$(mktemp -d)
      if [[ "$OS" == "linux" && "$ARCH" == "x86_64" ]]; then
        NVIM_ASSET="nvim-linux-x86_64.tar.gz"
      elif [[ "$OS" == "linux" && "$ARCH" == "aarch64" ]]; then
        NVIM_ASSET="nvim-linux-arm64.tar.gz"
      elif [[ "$OS" == "darwin" && "$ARCH" == "aarch64" ]]; then
        NVIM_ASSET="nvim-macos-arm64.tar.gz"
      else
        NVIM_ASSET="nvim-macos-x86_64.tar.gz"
      fi
      curl -fL --connect-timeout 30 --max-time 600 --retry 2 \
        "https://github.com/neovim/neovim/releases/download/${latest}/${NVIM_ASSET}" \
        -o "$tmpdir/nvim.tar.gz"
      tar -xzf "$tmpdir/nvim.tar.gz" -C "$tmpdir"
      NVIM_DIR=$(find "$tmpdir" -maxdepth 1 -name "nvim-*" -type d | head -1)
      install -m 755 "$NVIM_DIR/bin/nvim" "$BIN_DIR/nvim"
      # Runtime: syntax files, treesitter queries, ftplugins, etc.
      mkdir -p "$HOME/.local/share/nvim/runtime"
      cp -r "$NVIM_DIR/share/nvim/runtime/." "$HOME/.local/share/nvim/runtime/"
      # Bundled treesitter parsers (present since nvim 0.10)
      if [[ -d "$NVIM_DIR/lib/nvim" ]]; then
        mkdir -p "$HOME/.local/lib/nvim"
        cp -r "$NVIM_DIR/lib/nvim/." "$HOME/.local/lib/nvim/"
      fi
      rm -rf "$tmpdir"
      set_installed_version "nvim" "$latest"
      ok "nvim installed at ${latest}"
    else
      ok "nvim already at ${latest}"
    fi
  fi

  log "=== CLI tools ==="

  # dest | crate | repo | os | arch | glob | bin
  CLI_TOOLS=(
    "bat|bat|sharkdp/bat|linux|x86_64|bat-*-x86_64*linux*musl*.tar.gz|-"
    "bat|bat|sharkdp/bat|linux|aarch64|bat-*-aarch64*linux*musl*.tar.gz|-"
    "bat|bat|sharkdp/bat|darwin|*|bat-*-*apple*darwin*.tar.gz|-"

    "fd|fd-find|sharkdp/fd|linux|x86_64|fd-*-x86_64*linux*musl*.tar.gz|-"
    "fd|fd-find|sharkdp/fd|linux|aarch64|fd-*-aarch64*linux*musl*.tar.gz|-"
    "fd|fd-find|sharkdp/fd|darwin|*|fd-*-*apple*darwin*.tar.gz|-"

    "rg|ripgrep|BurntSushi/ripgrep|linux|x86_64|ripgrep-*-x86_64*linux*musl*.tar.gz|rg"
    "rg|ripgrep|BurntSushi/ripgrep|linux|aarch64|ripgrep-*-aarch64*linux*.tar.gz|rg"
    "rg|ripgrep|BurntSushi/ripgrep|darwin|*|ripgrep-*-*apple*darwin*.tar.gz|rg"

    "rga|ripgrep_all|phiresky/ripgrep-all|linux|x86_64|ripgrep_all-*-x86_64*linux*musl*.tar.gz|rga"
    "rga|ripgrep_all|phiresky/ripgrep-all|darwin|*|ripgrep_all-*-*apple*darwin*.tar.gz|rga"

    "eza|eza|eza-community/eza|linux|x86_64|eza_x86_64*linux*musl*.tar.gz|-"
    "eza|eza|eza-community/eza|linux|aarch64|eza_aarch64*linux*musl*.tar.gz|-"
    "eza|eza|eza-community/eza|darwin|*|eza_*apple*darwin*.tar.gz|-"

    "fzf|-|junegunn/fzf|linux|x86_64|fzf-*-linux_amd64.tar.gz|-"
    "fzf|-|junegunn/fzf|linux|aarch64|fzf-*-linux_arm64.tar.gz|-"
    "fzf|-|junegunn/fzf|darwin|x86_64|fzf-*-darwin_amd64.tar.gz|-"
    "fzf|-|junegunn/fzf|darwin|aarch64|fzf-*-darwin_arm64.tar.gz|-"

    "zoxide|zoxide|ajeetdsouza/zoxide|linux|x86_64|zoxide-*-x86_64*linux*musl*.tar.gz|-"
    "zoxide|zoxide|ajeetdsouza/zoxide|linux|aarch64|zoxide-*-aarch64*linux*musl*.tar.gz|-"
    "zoxide|zoxide|ajeetdsouza/zoxide|darwin|*|zoxide-*-*apple*darwin*.tar.gz|-"

    "lazygit|-|jesseduffield/lazygit|linux|x86_64|lazygit_*_Linux_x86_64.tar.gz|-"
    "lazygit|-|jesseduffield/lazygit|linux|aarch64|lazygit_*_Linux_arm64.tar.gz|-"
    "lazygit|-|jesseduffield/lazygit|darwin|*|lazygit_*_Darwin_*.tar.gz|-"

    "gping|gping|orf/gping|linux|x86_64|gping-Linux-musl-x86_64.tar.gz|-"
    "gping|gping|orf/gping|linux|aarch64|gping-Linux-musl-arm64.tar.gz|-"
    "gping|gping|orf/gping|darwin|x86_64|gping-macOS-x86_64.tar.gz|-"
    "gping|gping|orf/gping|darwin|aarch64|gping-macOS-arm64.tar.gz|-"

    "trip|trippy|fujiapple852/trippy|linux|x86_64|trippy-*-x86_64-unknown-linux-musl.tar.gz|trip"
    "trip|trippy|fujiapple852/trippy|linux|aarch64|trippy-*-aarch64-unknown-linux-musl.tar.gz|trip"
    "trip|trippy|fujiapple852/trippy|darwin|x86_64|trippy-*-x86_64-apple-darwin.tar.gz|trip"
    "trip|trippy|fujiapple852/trippy|darwin|aarch64|trippy-*-aarch64-apple-darwin.tar.gz|trip"

    "tldr|tealdeer|tealdeer-rs/tealdeer|linux|x86_64|tealdeer-linux-x86_64-musl|-"
    "tldr|tealdeer|tealdeer-rs/tealdeer|linux|aarch64|tealdeer-linux-aarch64-musl|-"
    "tldr|tealdeer|tealdeer-rs/tealdeer|darwin|*|tealdeer-macos|-"

    "tspin|tailspin|bensadeh/tailspin|linux|x86_64|tailspin-x86_64-unknown-linux-musl.tar.gz|-"
    "tspin|tailspin|bensadeh/tailspin|linux|aarch64|tailspin-aarch64-unknown-linux-musl.tar.gz|-"
    "tspin|tailspin|bensadeh/tailspin|darwin|*|tailspin-*-apple-darwin.tar.gz|-"

    "choose|choose|theryangeary/choose|linux|x86_64|choose-x86_64-unknown-linux-musl|-"
    "choose|choose|theryangeary/choose|darwin|*|choose-*-apple-darwin|-"

    "difft|difftastic|Wilfred/difftastic|linux|x86_64|difft-x86_64-unknown-linux-gnu.tar.gz|-"
    "difft|difftastic|Wilfred/difftastic|linux|aarch64|difft-aarch64-unknown-linux-gnu.tar.gz|-"
    "difft|difftastic|Wilfred/difftastic|darwin|x86_64|difft-x86_64-apple-darwin.tar.gz|-"
    "difft|difftastic|Wilfred/difftastic|darwin|aarch64|difft-aarch64-apple-darwin.tar.gz|-"

    "atuin|atuin|atuinsh/atuin|linux|x86_64|atuin-x86_64-unknown-linux-musl.tar.gz|-"
    "atuin|atuin|atuinsh/atuin|linux|aarch64|atuin-aarch64-unknown-linux-musl.tar.gz|-"
    "atuin|atuin|atuinsh/atuin|darwin|*|atuin-*-apple-darwin.tar.gz|-"

    "procs|procs|dalance/procs|linux|x86_64|procs-v*-x86_64*linux*.zip|-"
    "procs|procs|dalance/procs|darwin|*|procs-v*-*apple*darwin*.zip|-"

    "sd|sd|chmln/sd|linux|x86_64|sd-v*-x86_64*linux*musl*.tar.gz|-"
    "sd|sd|chmln/sd|darwin|*|sd-v*-*apple*darwin*.tar.gz|-"

    "viddy|-|sachaos/viddy|linux|x86_64|viddy-*-linux-x86_64.tar.gz|-"
    "viddy|-|sachaos/viddy|linux|aarch64|viddy-*-linux-arm64.tar.gz|-"
    "viddy|-|sachaos/viddy|darwin|x86_64|viddy-*-macos-x86_64.tar.gz|-"
    "viddy|-|sachaos/viddy|darwin|aarch64|viddy-*-macos-arm64.tar.gz|-"

    "ouch|ouch|ouch-org/ouch|linux|x86_64|ouch-x86_64-unknown-linux-musl.tar.gz|-"
    "ouch|ouch|ouch-org/ouch|linux|aarch64|ouch-aarch64-unknown-linux-musl.tar.gz|-"
    "ouch|ouch|ouch-org/ouch|darwin|*|ouch-*-apple-darwin.tar.gz|-"

    "presenterm|presenterm|mfontanini/presenterm|linux|x86_64|presenterm-*-x86_64*linux*musl*.tar.gz|-"
    "presenterm|presenterm|mfontanini/presenterm|darwin|*|presenterm-*-*apple*darwin*.tar.gz|-"

    "asciinema|-|asciinema/asciinema|linux|x86_64|asciinema-x86_64-unknown-linux-musl|-"
    "asciinema|-|asciinema/asciinema|linux|aarch64|asciinema-aarch64-unknown-linux-gnu|-"
    "asciinema|-|asciinema/asciinema|darwin|x86_64|asciinema-x86_64-apple-darwin|-"
    "asciinema|-|asciinema/asciinema|darwin|aarch64|asciinema-aarch64-apple-darwin|-"

    "btm|bottom|ClementTsang/bottom|linux|x86_64|bottom_x86_64-unknown-linux-musl.tar.gz|btm"
    "btm|bottom|ClementTsang/bottom|linux|aarch64|bottom_aarch64-unknown-linux-musl.tar.gz|btm"
    "btm|bottom|ClementTsang/bottom|darwin|*|bottom_*-apple-darwin.tar.gz|btm"

    "carapace|-|carapace-sh/carapace-bin|linux|x86_64|carapace-bin_*_linux_amd64.tar.gz|carapace"
    "carapace|-|carapace-sh/carapace-bin|linux|aarch64|carapace-bin_*_linux_arm64.tar.gz|carapace"
    "carapace|-|carapace-sh/carapace-bin|darwin|x86_64|carapace-bin_*_darwin_amd64.tar.gz|carapace"
    "carapace|-|carapace-sh/carapace-bin|darwin|aarch64|carapace-bin_*_darwin_arm64.tar.gz|carapace"
  )
  for t in "${CLI_TOOLS[@]}"; do install_tool "$t"; done

  log "=== Nushell plugins ==="

  # Cargo-only plugins — always try if cargo is present
  NUSHELL_PLUGINS_CARGO=(
    "nu_plugin_skim|nu_plugin_skim"
    "nu_plugin_dns|nu_plugin_dns"
    "nu_plugin_highlight|nu_plugin_highlight"
    #"nu_plugin_file|nu_plugin_file"
    #"nu_plugin_compress|nu_plugin_compress"
    #"nu_plugin_x509|nu_plugin_x509"d
    #"nu_plugin_clipboard|nu_plugin_clipboard"
  )
  PLUGIN_CARGO_BIN="$HOME/.cargo/bin/cargo"
  if [[ -x "$PLUGIN_CARGO_BIN" ]]; then
    export PATH="$HOME/.cargo/bin:$PATH"
    for entry in "${NUSHELL_PLUGINS_CARGO[@]}"; do
      IFS='|' read -r pdest pcrate <<< "$entry"
      cargo_install "$pcrate" "$pdest"
    done
  else
    warn "cargo not found — skipping all Nushell plugins (they require cargo)"
    warn "Install Rust via https://rustup.rs then re-run install.sh"
  fi

  # yazi (includes ya companion binary) — two binaries from the same archive
  # Always use binary releases: crates.io requires a yazi-build workaround that's unreliable
  if [[ "$OS" == "linux" && "$ARCH" == "x86_64" ]]; then
    download_release "sxyazi/yazi" "yazi-x86_64-unknown-linux-musl.zip" "yazi" "yazi"
    log "Extracting ya companion binary..."
    tmpdir=$(mktemp -d)
    latest_yazi=$(curl -sf "https://api.github.com/repos/sxyazi/yazi/releases/latest" \
      | grep -oP '"tag_name":\s*"\K[^"]+' | head -1)
    curl -sfL "https://github.com/sxyazi/yazi/releases/download/${latest_yazi}/yazi-x86_64-unknown-linux-musl.zip" \
      -o "$tmpdir/yazi.zip"
    unzip -q "$tmpdir/yazi.zip" -d "$tmpdir"
    ya_bin=$(find "$tmpdir" -name "ya" | head -1)
    [[ -f "$ya_bin" ]] && install -m 755 "$ya_bin" "$BIN_DIR/ya"
    rm -rf "$tmpdir"
  elif [[ "$OS" == "linux" && "$ARCH" == "aarch64" ]]; then
    download_release "sxyazi/yazi" "yazi-aarch64-unknown-linux-musl.zip" "yazi" "yazi"
  elif [[ "$OS" == "darwin" ]]; then
    download_release "sxyazi/yazi" "yazi-*-apple-darwin.zip" "yazi" "yazi"
  fi

  # mosh — no pre-built release binaries, use system package manager
  if ! command -v mosh &>/dev/null; then
    log "Installing mosh via system package manager..."
    if command -v apt-get &>/dev/null; then
      sudo apt-get install -y mosh 2>/dev/null && ok "mosh installed" || warn "mosh install failed (non-fatal)"
    elif command -v brew &>/dev/null; then
      brew install mosh && ok "mosh installed"
    else
      warn "mosh: please install manually (e.g. apt install mosh)"
    fi
  fi

  # ── Post-download: bat theme cache ────────────────────────────────────────
  log "=== Post-download setup ==="

  if [[ -f "$BIN_DIR/bat" ]]; then
    log "Installing Catppuccin bat theme..."
    BAT_CONFIG_DIR="$HOME/.config/bat"
    mkdir -p "$BAT_CONFIG_DIR/themes"
    if [[ ! -f "$BAT_CONFIG_DIR/themes/Catppuccin Mocha.tmTheme" ]]; then
      curl -sfL \
        "https://github.com/catppuccin/bat/raw/main/themes/Catppuccin%20Mocha.tmTheme" \
        -o "$BAT_CONFIG_DIR/themes/Catppuccin Mocha.tmTheme"
    fi
    "$BIN_DIR/bat" cache --build &>/dev/null && ok "bat theme cache built"
  fi

  # ── Nushell catppuccin theme ───────────────────────────────────────────────
  NUSHELL_THEME_DIR="$HOME/.config/nushell/themes"
  mkdir -p "$NUSHELL_THEME_DIR"
  if [[ ! -f "$NUSHELL_THEME_DIR/catppuccin_mocha.nu" ]]; then
    log "Downloading Nushell Catppuccin Mocha theme..."
    curl -sfL --connect-timeout 15 \
      "https://raw.githubusercontent.com/catppuccin/nushell/main/themes/catppuccin_mocha.nu" \
      -o "$NUSHELL_THEME_DIR/catppuccin_mocha.nu" \
      && ok "Nushell theme downloaded" \
      || warn "Nushell theme download failed — source manually from catppuccin/nushell"
  fi
  if [[ ! -f "$NUSHELL_THEME_DIR/catppuccin_mocha.tmTheme" ]]; then
    log "Downloading Nushell Plugin Highlight Catppuccin Mocha theme..."
    curl -sfL --connect-timeout 15 \
      "https://github.com/catppuccin/bat/raw/main/themes/Catppuccin%20Mocha.tmTheme" \
      -o "$NUSHELL_THEME_DIR/catppuccin_mocha.tmTheme" \
      && ok "Nushell Highlight theme downloaded" \
      || warn "Nushell Highlight theme download failed — source manually from catppuccin/bat"
  fi

fi  # end --link / skip downloads

# ── Package list (shared by deploy and remove) ────────────────────────────────
PACKAGES=(
  bin bash nushell starship zellij nvim
  git ripgrep bat yazi atuin lazygit tealdeer ssh alacritty
)

# ── Remove deployed symlinks ──────────────────────────────────────────────────
remove_package() {
  local pkg_dir="$DOTFILES/$1"
  [[ -d "$pkg_dir" ]] || return
  while IFS= read -r -d '' src; do
    local rel="${src#$pkg_dir/}"
    local target="$HOME/$rel"
    if [[ -L "$target" ]]; then
      rm "$target"
      ok "Removed $target"
    fi
  done < <(find "$pkg_dir" -type f -print0 2>/dev/null)
}

if [[ "$DO_REMOVE" == true ]]; then
  log "=== Removing deployed symlinks ==="
  for pkg in "${PACKAGES[@]}"; do
    remove_package "$pkg"
  done
  ok "Done — symlinks removed. Binaries in $BIN_DIR are untouched."
  exit 0
fi

# ── Deploy configs ────────────────────────────────────────────────────────────
[[ "$USE_COPY" == true ]] && log "=== Copying configs ===" || log "=== Linking configs ==="

BACKUP_SUFFIX=".bak.$(date +%Y%m%d%H%M%S)"

link_package() {
  local pkg_dir="$DOTFILES/$1"
  if [[ ! -d "$pkg_dir" ]]; then
    warn "Package not found: $1 (skipping)"
    return
  fi
  # Load ignore patterns from .linkignore in the package root (one glob per line, # = comment)
  local -a ignore_patterns=()
  local ignore_file="$pkg_dir/.linkignore"
  if [[ -f "$ignore_file" ]]; then
    while IFS= read -r pattern; do
      [[ -z "$pattern" || "$pattern" == \#* ]] && continue
      ignore_patterns+=("$pattern")
    done < "$ignore_file"
  fi
  while IFS= read -r -d '' src; do
    local rel="${src#$pkg_dir/}"
    # Skip .linkignore itself and files matching any ignore pattern
    local skip=false
    [[ "$rel" == ".linkignore" ]] && skip=true
    for pat in "${ignore_patterns[@]}"; do
      # shellcheck disable=SC2254
      case "$rel" in $pat) skip=true; break ;; esac
    done
    [[ "$skip" == true ]] && continue
    local target="$HOME/$rel"
    mkdir -p "$(dirname "$target")"
    if [[ -e "$target" && ! -L "$target" ]]; then
      warn "Backing up: $target → ${target}${BACKUP_SUFFIX}"
      mv "$target" "${target}${BACKUP_SUFFIX}"
    fi
    if [[ "$USE_COPY" == true ]]; then
      cp "$src" "$target"
    else
      ln -sf "$src" "$target"
    fi
  done < <(find "$pkg_dir" -type f -print0 2>/dev/null)
  [[ "$USE_COPY" == true ]] && ok "Copied $1" || ok "Linked $1"
}

for pkg in "${PACKAGES[@]}"; do
  link_package "$pkg"
done

# ── Nushell plugin registration ───────────────────────────────────────────────
log "=== Registering Nushell plugins ==="
NU_BIN="${LOCAL_BIN}/nu"
[[ -f "$NU_BIN" ]] || NU_BIN="$(command -v nu 2>/dev/null)" || true
if [[ -n "${NU_BIN:-}" && -x "${NU_BIN}" ]]; then
  for entry in "${NUSHELL_PLUGINS_CARGO[@]}"; do
    IFS='|' read -r plugin _ <<< "$entry"
    plugin_path="${LOCAL_BIN}/${plugin}"
    plugin_short="${plugin#nu_plugin_}"
    if [[ -f "$plugin_path" ]]; then
      if "${NU_BIN}" -c "plugin add $plugin_path" 2>/dev/null && \
         "${NU_BIN}" -c "plugin use ${plugin_short}" 2>/dev/null; then
        ok "Registered ${plugin}"
      else
        warn "Failed to register ${plugin} — run: nu -c 'plugin add ${plugin_path}; plugin use ${plugin_short}'"
      fi
    fi
  done
else
  warn "nu not found — skipping plugin registration. Re-run install.sh after nu is on PATH."
fi

# ── Neovim: headless plugin install ──────────────────────────────────────────
if [[ -f "$LOCAL_BIN/nvim" ]] || command -v nvim &>/dev/null; then
  NVIM_CMD="${LOCAL_BIN}/nvim"
  [[ -f "$NVIM_CMD" ]] || NVIM_CMD="nvim"
  if [[ ! -f "$HOME/.local/share/nvim/runtime/syntax/syntax.vim" ]]; then
    warn "nvim runtime missing — skipping headless plugin install. Run install.sh again after nvim downloads."
  else
    log "Installing Neovim plugins (headless — this may take a minute)..."
    VIMRUNTIME="$HOME/.local/share/nvim/runtime" \
      "$NVIM_CMD" --headless '+Lazy! sync' +qa 2>&1 | tail -5 \
      || warn "nvim plugins: some issues encountered — run :Lazy sync manually"
    ok "Neovim plugins installed"
  fi
fi

# ── Generate shell init scripts ───────────────────────────────────────────────
log "=== Generating shell init scripts ==="

if [[ ! -f "$HOME/.local/share/atuin/init.nu" ]] && { command -v atuin &>/dev/null || [[ -f "$LOCAL_BIN/atuin" ]]; }; then
  ATUIN="${LOCAL_BIN}/atuin"; [[ -f "$ATUIN" ]] || ATUIN="atuin"
  "$ATUIN" init nu --disable-up-arrow > "$HOME/.local/share/atuin/init.nu" 2>/dev/null && ok "atuin init generated"
fi

if [[ ! -f "$HOME/.cache/starship/init.nu" ]] && { command -v starship &>/dev/null || [[ -f "$LOCAL_BIN/starship" ]]; }; then
  STARSHIP="${LOCAL_BIN}/starship"; [[ -f "$STARSHIP" ]] || STARSHIP="starship"
  mkdir -p "$HOME/.cache/starship"
  "$STARSHIP" init nu > "$HOME/.cache/starship/init.nu" 2>/dev/null && ok "starship init generated"
fi

if [[ ! -f "$HOME/.local/share/zoxide/init.nu" ]] && { command -v zoxide &>/dev/null || [[ -f "$LOCAL_BIN/zoxide" ]]; }; then
  ZOXIDE="${LOCAL_BIN}/zoxide"; [[ -f "$ZOXIDE" ]] || ZOXIDE="zoxide"
  mkdir -p "$HOME/.local/share/zoxide"
  "$ZOXIDE" init nushell > "$HOME/.local/share/zoxide/init.nu" 2>/dev/null && ok "zoxide init generated"
fi

# Use ! -s (not non-empty) since the file is pre-touched empty in directory setup
if [[ ! -s "$HOME/.cache/carapace/init.nu" ]] && { command -v carapace &>/dev/null || [[ -f "$LOCAL_BIN/carapace" ]]; }; then
  CARAPACE="${LOCAL_BIN}/carapace"; [[ -f "$CARAPACE" ]] || CARAPACE="carapace"
  "$CARAPACE" _carapace nushell > "$HOME/.cache/carapace/init.nu" 2>/dev/null && ok "carapace init generated"
fi

# ── Yazi: install catppuccin-mocha flavor ─────────────────────────────────────
if command -v ya &>/dev/null || [[ -f "$LOCAL_BIN/ya" ]]; then
  YA="${LOCAL_BIN}/ya"
  [[ -f "$YA" ]] || YA="ya"
  log "Installing yazi catppuccin-mocha flavor..."
  # ya pkg add exits 1 if already in package.toml; treat that as success and
  # always run install to ensure the flavor files are actually deployed.
  ya_out=$("$YA" pkg add yazi-rs/flavors:catppuccin-mocha 2>&1) || \
    echo "$ya_out" | grep -q "already exists"
  if "$YA" pkg install 2>/dev/null; then
    ok "yazi catppuccin-mocha flavor installed"
  else
    warn "yazi flavor install failed — run 'ya pkg add yazi-rs/flavors:catppuccin-mocha' manually"
# ── Fonts (Linux / macOS only — WSL defers to windows-setup.ps1) ─────────────
if [[ "$IS_WSL" == false ]]; then
  log "=== JetBrainsMono Nerd Font ==="
  FONT_KEY="jetbrainsmono-nf"
  installed_font_ver=$(get_installed_version "$FONT_KEY")

  font_api_response=""
  font_latest=""
  if [[ -z "$installed_font_ver" || "$FORCE_UPDATE" == true ]]; then
    font_api_response=$(curl -sf --connect-timeout 15 --retry 3 --retry-delay 2 \
      "${GITHUB_AUTH[@]}" "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest") || true
    font_latest=$(echo "$font_api_response" | grep -oP '"tag_name":\s*"\K[^"]+' | head -1) || true
  fi

  if [[ -n "$installed_font_ver" && "$FORCE_UPDATE" == false ]]; then
    ok "JetBrainsMono Nerd Font already at ${installed_font_ver}"
  elif [[ -z "$font_latest" ]]; then
    warn "Could not fetch JetBrainsMono Nerd Font version — skipping."
  elif [[ "$installed_font_ver" == "$font_latest" && "$FORCE_UPDATE" == false ]]; then
    ok "JetBrainsMono Nerd Font already at ${font_latest}"
  else
    log "Downloading JetBrainsMono Nerd Font ${font_latest}..."
    font_zip_url=$(echo "$font_api_response" \
      | grep '"browser_download_url"' \
      | grep 'JetBrainsMono\.zip' \
      | cut -d'"' -f4 | head -1) || true

    if [[ -z "$font_zip_url" ]]; then
      warn "Could not find JetBrainsMono.zip asset — skipping font install."
    else
      font_tmp=$(mktemp -d)
      trap "rm -rf '$font_tmp'" RETURN

      if curl -fL --connect-timeout 30 --max-time 600 --retry 2 "$font_zip_url" -o "$font_tmp/JetBrainsMono.zip"; then
        unzip -q "$font_tmp/JetBrainsMono.zip" -d "$font_tmp/fonts"

        if [[ "$OS" == "darwin" ]]; then
          FONT_DEST="$HOME/Library/Fonts"
        else
          FONT_DEST="$HOME/.local/share/fonts"
        fi
        mkdir -p "$FONT_DEST"

        # Install NF, NFM, NFP — exclude NL variants (JetBrainsMonoNL*)
        font_count=0
        while IFS= read -r -d '' ttf; do
          cp "$ttf" "$FONT_DEST/"
          (( font_count++ )) || true
        done < <(find "$font_tmp/fonts" -name "JetBrainsMonoNerdFont*.ttf" -print0)

        [[ "$OS" == "linux" ]] && fc-cache -f "$FONT_DEST" 2>/dev/null || true
        set_installed_version "$FONT_KEY" "$font_latest"
        ok "JetBrainsMono Nerd Font installed (${font_count} files) at ${font_latest}"
      else
        warn "Font download failed — skipping."
      fi
    fi
  fi
fi

# ── SSH socket directory ───────────────────────────────────────────────────────
mkdir -p "$HOME/.ssh/sockets"
chmod 700 "$HOME/.ssh"
[[ -f "$HOME/.ssh/config" ]] && chmod 600 "$HOME/.ssh/config" || true

# ── Windows / Alacritty setup (WSL2 only) ─────────────────────────────────────
if [[ "$IS_WSL" == true && "$NO_WINDOWS" == false ]]; then
  log "=== Windows setup (WSL2 detected) ==="

  # Check WSL interop before attempting any powershell.exe calls
  WSL_INTEROP_OK=false
  if [[ "$(head -1 /proc/sys/fs/binfmt_misc/WSLInterop 2>/dev/null)" == "enabled" ]]; then
    WSL_INTEROP_OK=true
  elif command -v powershell.exe &>/dev/null && powershell.exe -NonInteractive -c "exit 0" &>/dev/null; then
    WSL_INTEROP_OK=true
  fi

  if [[ "$WSL_INTEROP_OK" == false ]]; then
    warn "WSL interop is disabled — skipping Windows setup (Alacritty, fonts)."
    warn "To enable: add 'enabled=true' under [interop] in /etc/wsl.conf, then run 'wsl --shutdown' and reopen."
  else

  # Detect WSL distro name
  DISTRO_NAME=$(powershell.exe -NonInteractive -c "wsl.exe --list --running --quiet" 2>/dev/null \
    | tr -d '\r\0' | grep -v '^$' | head -1) || true
  [[ -z "$DISTRO_NAME" ]] && \
    DISTRO_NAME=$(grep "^NAME=" /etc/os-release 2>/dev/null | cut -d'"' -f2 | tr ' ' '-')

  # Build Windows path to the alacritty.toml source file in dotfiles
  WIN_CONFIG_TARGET=""
  if [[ "$DOTFILES" =~ ^/mnt/([a-zA-Z])(/.*)$ ]]; then
    DRIVE="${BASH_REMATCH[1]^^}"
    REST="${BASH_REMATCH[2]}"
    WIN_CONFIG_TARGET="${DRIVE}:${REST//\//\\}\\alacritty\\.config\\alacritty\\alacritty.toml"
  else
    WIN_CONFIG_TARGET="\\\\wsl.localhost\\${DISTRO_NAME}${DOTFILES//\//\\}\\alacritty\\.config\\alacritty\\alacritty.toml"
  fi

  PS_WIN_PATH=$(wslpath -w "$DOTFILES/windows-setup.ps1")
  log "Running Windows setup (Alacritty, font, config)..."
  powershell.exe -NonInteractive -ExecutionPolicy Bypass \
    -File "$PS_WIN_PATH" -AlacrittyTarget "$WIN_CONFIG_TARGET" 2>&1 \
    | tr -d '\r\0' | grep -v "^$" \
    || warn "PowerShell step had warnings (non-fatal)"

  fi  # end WSL_INTEROP_OK
fi  # end IS_WSL

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${GREEN}║        Dotfiles installed successfully!          ║${RESET}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${CYAN}Next steps:${RESET}"
echo "  1. Start Nushell:  nu"
echo "  2. Zellij auto-starts — press \` to enter prefix mode"
echo "  3. Open Neovim:    nvim  (then :Lazy sync to install plugins)"
echo "  4. Update all:     ./install.sh --update"
echo ""
if [[ "$IS_WSL" == true ]]; then
  echo -e "${CYAN}Windows:${RESET}"
  echo "  • Open Alacritty — font and theme should load automatically"
  echo "  • If symlink failed, see manual steps printed above"
  echo ""
fi
