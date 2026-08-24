# .bashrc — minimal bash config; hands off to zsh for interactive sessions

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# Exec into zsh for interactive sessions. zsh is a required system package
# (install.sh checks for it, doesn't install it — see the "zsh install
# method" note in CLAUDE.md), so check PATH rather than a hardcoded
# ~/.local/bin path the way a download_release()-installed tool would.
# Falls back to bash if zsh isn't installed yet.
if [[ $- == *i* ]] && command -v zsh &>/dev/null; then
  exec zsh
fi
