# .bashrc — minimal bash config; hands off to Nushell for interactive sessions

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# Exec into Nushell for interactive sessions.
# Falls back to bash if nu isn't installed yet (e.g. before running install.sh).
if [[ $- == *i* ]] && [[ -x "$HOME/.local/bin/nu" ]]; then
  exec "$HOME/.local/bin/nu"
fi
