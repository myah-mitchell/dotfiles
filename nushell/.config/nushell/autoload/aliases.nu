# ── Aliases: specialty Rust tools ─────────────────────────────────────────────

# bat (cat)
alias bat  = bat --style header,grid
alias cat  = bat --style header,grid

# fd (find)
alias find = fd

# tailspin (tail)
alias tail = tspin

# ripgrep (grep)
alias grep = rg

# difftastic (diff)
alias diff = difft

# procs (ps)
alias ps   = procs

# viddy (watch)
alias watch = viddy

# bottom
alias btm  = btm

# sd — standalone, no alias override
# (use `sd` directly; does not replace sed)

# ── Aliases: nvim ────────────────────────────────-----────────────────────────
alias vi   = nvim
#alias vim  = nvim

# ── Aliases: shell nav ────────────────────────────────────────────────────────
alias lg   = lazygit
alias tldr = tldr
alias trip = trip
alias gping = gping

# ── Git shortcuts using difftastic ───────────────────────────────────────────
alias gd   = git diff
alias gds  = git diff --staged
alias gsh  = git show
alias gst  = git status -sb
alias glog = git log --oneline --graph --decorate --all


# ── Random ───────────────────────────────────────────────────────────────────

alias l     = ls -alt