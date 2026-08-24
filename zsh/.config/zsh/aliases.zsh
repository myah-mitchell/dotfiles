# ── Aliases: specialty Rust tools ─────────────────────────────────────────────

# bat (cat)
alias bat='bat --style header,grid'
alias cat='bat --style header,grid'

# zoxide (cd)
alias cd='z'

# fd (find)
alias find='fd'

# tailspin (tail)
alias tail='tspin'

# ripgrep (grep)
alias grep='rg'

# difftastic (diff)
alias diff='difft'

# procs (ps)
alias ps='procs'

# viddy (watch)
alias watch='viddy'

# bottom
alias btm='btm'

# eza (ls) — Catppuccin Mocha theme via $EZA_CONFIG_DIR/theme.yml (zsh/.zshenv)
alias ls='eza --icons=auto --group-directories-first'

# sd — standalone, no alias override
# (use `sd` directly; does not replace sed)

# ── Aliases: nvim ────────────────────────────────────────────────────────────
alias vi='nvim'

# ── Aliases: shell nav ────────────────────────────────────────────────────────
alias lg='lazygit'
alias tldr='tldr'
alias trip='trip'
alias gping='gping'

# ── Git shortcuts using difftastic ───────────────────────────────────────────
alias gd='git diff'
alias gds='git diff --staged'
alias gsh='git show'
alias gst='git status -sb'
alias glog='git log --oneline --graph --decorate --all'

# ── Random ───────────────────────────────────────────────────────────────────
# eza has no GNU-ls-style -t flag (its -t/--time picks *which* timestamp to
# show, not sort order) and --sort=modified alone already sorts oldest-first
# (newest last) — the equivalent of GNU `ls -tr`, which is what this is going
# for. Adding --reverse here would flip it to newest-first instead.
alias l='ls -al --sort=modified'
