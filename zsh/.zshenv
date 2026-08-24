# .zshenv — environment variables only, sourced on every zsh invocation
# (interactive, scripts, non-interactive) before .zshrc.

# ── PATH ─────────────────────────────────────────────────────────────────────
typeset -U path
path=(
  "$HOME/.local/bin"
  "$HOME/.cargo/bin"
  "$HOME/go/bin"
  /usr/local/bin
  /usr/bin
  /bin
  $path
)
export PATH

# ── XDG base directories ─────────────────────────────────────────────────────
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"

# ── Editors ───────────────────────────────────────────────────────────────────
export EDITOR="nvim"
export VISUAL="nvim"
export VIMRUNTIME="$HOME/.local/share/nvim/runtime"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# ── Diff / Git ────────────────────────────────────────────────────────────────
export GIT_EXTERNAL_DIFF="difft"
export DIFFTASTIC_DISPLAY="side-by-side-show-both"

# ── Ripgrep ───────────────────────────────────────────────────────────────────
export RIPGREP_CONFIG_PATH="$HOME/.config/ripgrep/ripgreprc"

# ── Bat ───────────────────────────────────────────────────────────────────────
export BAT_THEME="Catppuccin Mocha"

# ── eza ───────────────────────────────────────────────────────────────────────
# Theme downloaded by install.sh from catppuccin/eza to $EZA_CONFIG_DIR/theme.yml
export EZA_CONFIG_DIR="$HOME/.config/eza"

# ── FZF — catppuccin mocha palette ────────────────────────────────────────────
export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"
export FZF_DEFAULT_OPTS="
  --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8
  --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc
  --color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8
  --color=selected-bg:#45475a,border:#313244
  --layout=reverse --border=rounded --height=40%
  --preview-window=border-rounded
"

# ── Zellij auto-attach ────────────────────────────────────────────────────────
export ZELLIJ_AUTO_ATTACH="true"
export ZELLIJ_AUTO_EXIT="false"

# ── Starship cache ────────────────────────────────────────────────────────────
export STARSHIP_CACHE="$HOME/.cache/starship"

# ── Pager ─────────────────────────────────────────────────────────────────────
export LESS="-R --mouse"
export PAGER="less"

# ── Locale ────────────────────────────────────────────────────────────────────
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# ── Colors ────────────────────────────────────────────────────────────────────
export COLORTERM="truecolor"
export TERM_PROGRAM="${TERM_PROGRAM:-}"

# ── Secrets (not committed — edit ~/.config/zsh/secrets.zsh) ─────────────────
# e.g. export GITHUB_TOKEN="ghp_..."
# Guarded rather than pre-touched: zsh's source is a runtime check (unlike
# Nu's parse-time-only source), so this file doesn't need to exist for this
# line to be safe — install.sh doesn't need to pre-seed it empty.
[[ -f ~/.config/zsh/secrets.zsh ]] && source ~/.config/zsh/secrets.zsh
