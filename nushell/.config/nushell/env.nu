# env.nu — environment variables only (no output allowed here)
# Sourced before config.nu on every Nushell startup.

# ── PATH ─────────────────────────────────────────────────────────────────────
$env.PATH = (
  $env.PATH
  | split row (char esep)
  | prepend [
      ($env.HOME | path join ".local" "bin")
      ($env.HOME | path join ".cargo" "bin")
      ($env.HOME | path join "go" "bin")
      "/usr/local/bin"
      "/usr/bin"
      "/bin"
    ]
  | uniq
)

# ── XDG base directories ─────────────────────────────────────────────────────
$env.XDG_CONFIG_HOME = ($env.HOME | path join ".config")
$env.XDG_DATA_HOME   = ($env.HOME | path join ".local" "share")
$env.XDG_CACHE_HOME  = ($env.HOME | path join ".cache")
$env.XDG_STATE_HOME  = ($env.HOME | path join ".local" "state")

# ── Editors ───────────────────────────────────────────────────────────────────
$env.EDITOR  = "nvim"
$env.VISUAL  = "nvim"
$env.VIMRUNTIME = ($env.HOME | path join ".local" "share" "nvim" "runtime")
$env.MANPAGER = "sh -c 'col -bx | bat -l man -p'"

# ── Diff / Git ────────────────────────────────────────────────────────────────
$env.GIT_EXTERNAL_DIFF = "difft"
$env.DIFFTASTIC_DISPLAY = "side-by-side-show-both"

# ── Ripgrep ───────────────────────────────────────────────────────────────────
$env.RIPGREP_CONFIG_PATH = ($env.HOME | path join ".config" "ripgrep" "ripgreprc")

# ── Bat ───────────────────────────────────────────────────────────────────────
$env.BAT_THEME = "Catppuccin Mocha"

# ── FZF — catppuccin mocha palette ────────────────────────────────────────────
$env.FZF_DEFAULT_COMMAND = "fd --type f --hidden --follow --exclude .git"
$env.FZF_DEFAULT_OPTS = "
  --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8
  --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc
  --color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8
  --color=selected-bg:#45475a,border:#313244
  --layout=reverse --border=rounded --height=40%
  --preview-window=border-rounded
"

# ── Zellij auto-attach ────────────────────────────────────────────────────────
$env.ZELLIJ_AUTO_ATTACH = "true"
$env.ZELLIJ_AUTO_EXIT   = "false"

# ── Starship cache ────────────────────────────────────────────────────────────
$env.STARSHIP_CACHE = ($env.HOME | path join ".cache" "starship")

# ── Pager ─────────────────────────────────────────────────────────────────────
$env.LESS = "-R --mouse"
$env.PAGER = "less"

# ── Locale ────────────────────────────────────────────────────────────────────
$env.LANG   = "en_US.UTF-8"
$env.LC_ALL = "en_US.UTF-8"

# ── Colors ────────────────────────────────────────────────────────────────────
$env.COLORTERM = "truecolor"
$env.TERM_PROGRAM = ($env.TERM_PROGRAM? | default "")

# ── Secrets (not committed — edit ~/.config/nushell/secrets.nu) ──────────────
# e.g. $env.GITHUB_TOKEN = "ghp_..."
# install.sh creates this file empty if it doesn't exist so source always works.
source ~/.config/nushell/secrets.nu

# ── WSL clipboard helper ──────────────────────────────────────────────────────
# Make wl-copy/wl-paste available via clip.exe on WSL2
# (Neovim clipboard provider falls back to this automatically)
