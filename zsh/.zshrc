# .zshrc — interactive shell configuration, sourced after .zshenv

# ── History ───────────────────────────────────────────────────────────────────
HISTFILE="$HOME/.local/share/zsh/history"
HISTSIZE=1000000
SAVEHIST=1000000
mkdir -p "${HISTFILE:h}"
setopt SHARE_HISTORY       # write/read history incrementally across sessions
setopt INC_APPEND_HISTORY  # append each command as it's run, not at shell exit
setopt HIST_IGNORE_DUPS    # don't record a line if it duplicates the previous one
setopt HIST_IGNORE_SPACE   # don't record lines starting with a space
# atuin owns fuzzy/synced history search (Ctrl+R, bound by its own init below);
# this HISTFILE is just zsh's own plain backing store.

# ── Editing ───────────────────────────────────────────────────────────────────
# Emacs keybindings (zsh's default — no modal insert/normal split). Vi mode
# (bindkey -v) was tried for parity with Nu's edit_mode: vi and with Neovim,
# but its modal state kept getting entered by accident (a stray Esc-prefixed
# escape sequence — Home/Delete/arrows all start with one — landing you in vi
# command mode, where ordinary letters act as commands instead of inserting
# text, and `~` specifically toggles the case of the character under the
# cursor). bindkey -e forces emacs mode explicitly rather than relying on
# zsh's own EDITOR/VISUAL-based default-keymap detection.
bindkey -e
unsetopt BEEP               # no terminal bell (and no visual-bell screen flash it
                             # triggers) on tab-complete-no-match, empty backspace, etc.

# KEYTIMEOUT is how long (in hundredths of a second) zsh waits after a lone
# ESC byte to see if more bytes follow as part of a longer escape sequence
# (arrow keys, Delete, Home/End all start with ESC — as do emacs mode's own
# Alt-key combos, which terminals send as Esc+key). The 40 (400ms) default is
# tuned for old slow serial links; on a modern terminal the whole sequence
# arrives in one read(), but if it's ever a beat late — WSL2, Zellij
# passthrough, just typing fast — zsh can misread a split sequence. 1 (10ms)
# all but eliminates that race.
KEYTIMEOUT=1

# Terminfo-based bindings for Delete/Home/End/PageUp/PageDown so they're
# recognized as a single bound action rather than depending on the emacs
# keymap's own defaults (which don't cover all of these on every system).
[[ -n "${terminfo[kdch1]}" ]] && bindkey -M emacs "${terminfo[kdch1]}" delete-char
[[ -n "${terminfo[khome]}" ]] && bindkey -M emacs "${terminfo[khome]}" beginning-of-line
[[ -n "${terminfo[kend]}"  ]] && bindkey -M emacs "${terminfo[kend]}"  end-of-line
# terminfo's khome/kend report the *application cursor-key mode* sequences
# (^[OH / ^[OF), but zsh's line editor never puts the terminal into that
# mode — at a bare prompt Alacritty sends the *normal-mode* forms instead
# (^[[H / ^[[F), which the terminfo lookup above misses entirely. Some
# terminals (rxvt/putty-style) use a third, numbered form (^[[1~ / ^[[4~).
# Bind all three directly so it works regardless of which one is actually
# in flight.
bindkey -M emacs '^[[H' beginning-of-line
bindkey -M emacs '^[[1~' beginning-of-line
bindkey -M emacs '^[[F' end-of-line
bindkey -M emacs '^[[4~' end-of-line
# PageUp/PageDown -> cycle history entries that start with whatever's already
# typed (the standard readline/bash convention) — a quick prefix-based
# complement to atuin's fuzzy full-text Ctrl+R search above.
[[ -n "${terminfo[kpp]}" ]] && bindkey -M emacs "${terminfo[kpp]}" history-beginning-search-backward
[[ -n "${terminfo[knp]}" ]] && bindkey -M emacs "${terminfo[knp]}" history-beginning-search-forward

# ── Completion ────────────────────────────────────────────────────────────────
autoload -Uz compinit
compinit
zstyle ':completion:*' menu select
# Case-insensitive matching. Tried 'exact match first, case-insensitive
# fallback' (matcher-list '' 'm:{a-zA-Z}={A-Za-z}') so same-name case
# duplicates (Foo.txt/foo.txt) would resolve to the exact typed case instead
# of listing both — but zsh's matcher-list picks the *first* spec with *any*
# match and stops there, so it also hid genuinely different files: with
# read-this.md and README.md both present, typing r<Tab> matched
# read-this.md exactly and never even considered README.md. That's worse, so
# back to plain folding — every case-insensitive match is shown; the rare
# same-name-different-case collision just shows up as an ambiguous pair too.
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
# LIST_AMBIGUOUS is on by default: when there's a common prefix to insert,
# zsh inserts it *without* showing the menu, requiring a second Tab press to
# actually see it — the classic "why do I have to hit Tab twice" complaint.
# Unset it so the grid menu appears on the very first Tab whenever the match
# isn't already unambiguous (single match still just completes normally).
unsetopt LIST_AMBIGUOUS

# ── SSH agent ─────────────────────────────────────────────────────────────────
_ssh_agent_socket="$HOME/.ssh/ssh-agent.sock"
if [[ ! -S "$_ssh_agent_socket" ]]; then
  ssh-agent -a "$_ssh_agent_socket" |
    awk -F'[=;]' '/SSH_AGENT_PID/ {print $2}' >"$HOME/.ssh/ssh-agent.pid"
fi
export SSH_AUTH_SOCK="$_ssh_agent_socket"
unset _ssh_agent_socket

# ── Tool integrations ─────────────────────────────────────────────────────────
[[ -f ~/.local/share/zoxide/init.zsh ]] && source ~/.local/share/zoxide/init.zsh
[[ -f ~/.local/share/atuin/init.zsh ]] && source ~/.local/share/atuin/init.zsh
[[ -f ~/.cache/starship/init.zsh ]] && source ~/.cache/starship/init.zsh
[[ -f ~/.cache/carapace/init.zsh ]] && source ~/.cache/carapace/init.zsh

# Carapace bridges ~700 commands — including cp/ls/mv/rm/cat/mkdir/etc — to
# its own external completion engine, which generates and filters candidates
# itself (via the carapace binary) before zsh's matcher-list zstyle above
# ever sees them. That's why the case-insensitive fold matching set up in
# the Completion section works for some things but not these: it's not a
# matcher-list bug, carapace's own candidate generation just never goes
# through zsh's native matching at all. Hand the everyday file-manipulation
# commands back to zsh's own bundled completers (which do respect
# matcher-list) so path completion for them stays case-insensitive; carapace
# keeps everything else (git, docker, kubectl, and the rest of its ~700).
compdef _ls ls
compdef _cp cp
compdef _mv mv
compdef _rm rm
compdef _cat cat
compdef _mkdir mkdir
compdef _rmdir rmdir
compdef _touch touch
compdef _ln ln

# ── Zellij auto-start ─────────────────────────────────────────────────────────
# Only start Zellij if we're not already inside it and it's an interactive
# session. The $NVIM guard stops a terminal opened *inside* Neovim
# (snacks/toggleterm) from spawning a nested Zellij in the terminal buffer,
# even when nvim runs outside Zellij.
zellij_autostart() {
  if [[ -z "$ZELLIJ" && -z "$NVIM" ]]; then
    if [[ "$ZELLIJ_AUTO_ATTACH" == "true" ]]; then
      zellij attach --create --remember default
    else
      zellij
    fi
    [[ "$ZELLIJ_AUTO_EXIT" == "false" ]] && return
    exit
  fi
}
[[ -o interactive ]] && zellij_autostart

# ── Yazi wrapper — changes directory on exit ──────────────────────────────────
y() {
  local tmp cwd
  tmp=$(mktemp -t "yazi-cwd.XXXXXX")
  yazi "$@" --cwd-file "$tmp"
  cwd=$(cat "$tmp")
  [[ -n "$cwd" && "$cwd" != "$PWD" ]] && cd "$cwd"
  rm -f "$tmp"
}

# ── sudo — preserve user PATH so ~/.local/bin tools are visible ───────────────
# sudo's secure_path (set in /etc/sudoers) strips PATH by default, independent
# of shell; this wrapper re-injects PATH so `sudo bat`, `sudo rg`, etc. find
# the tools installed in ~/.local/bin. `sudo !!` to re-run the last command
# with sudo needs no separate helper here — zsh's built-in `!!` history
# expansion already does that (Nu needed a dedicated `sudo!!` command because
# it has no history-expansion syntax).
#
# sudo's own flags (`-s`, `-u user`, `-i`, ...) must come before the target
# command, not after it — blindly prepending `env "PATH=$PATH"` to "$@" put
# it ahead of those flags too, so sudo saw `env` (or `PATH=...`) as the flag's
# argument instead (e.g. `sudo -s` became `sudo env PATH=... -s`, handing "-s"
# to env, not sudo). zparseopts splits sudo's leading flags off into `opts`
# first, so `env PATH=...` only ever gets inserted right before the actual
# command, and is skipped entirely for a bare `sudo -s`/`sudo -u user`/`sudo -i`
# with no trailing command. Covers the common short options; an unlisted or
# long (`--foo`) option just stops the split early and rides through as part
# of the command args, same as sudo would already reject it.
sudo() {
  local -a opts
  zparseopts -D -a opts -- \
    A b B E e H h i K k l n P S s V v \
    C: D: g: p: R: T: U: u:
  if (( $# )); then
    command sudo "${opts[@]}" env "PATH=$PATH" "$@"
  else
    command sudo "${opts[@]}"
  fi
}

# ── Keybindings ───────────────────────────────────────────────────────────────
# Ctrl+F — fzf file picker, insert path at cursor (Ctrl+R is bound by atuin's
# own init above)
fzf-file-widget-insert() {
  local file
  file=$(fzf --popup --prompt 'File> ')
  LBUFFER+="$file"
  zle redisplay
}
zle -N fzf-file-widget-insert
bindkey -M emacs '^F' fzf-file-widget-insert

# ── Aliases ───────────────────────────────────────────────────────────────────
[[ -f ~/.config/zsh/aliases.zsh ]] && source ~/.config/zsh/aliases.zsh

# ── Plugins (source last, syntax-highlighting absolutely last — it must load
# after anything else that wraps zle widgets) ─────────────────────────────────
# No official catppuccin/zsh-autosuggestions port exists (unlike the syntax
# highlighting theme below), so this is a manual pick matching Catppuccin
# Mocha's "overlay0" gray — set before sourcing, since the plugin only fills
# in its own default when unset.
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#6c7086'
[[ -f ~/.local/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh ]] &&
  source ~/.local/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh
[[ -f ~/.local/share/zsh/plugins/zsh-you-should-use/you-should-use.plugin.zsh ]] &&
  source ~/.local/share/zsh/plugins/zsh-you-should-use/you-should-use.plugin.zsh

# Catppuccin Mocha colors for zsh-syntax-highlighting — must be sourced
# *before* the plugin itself (sets ZSH_HIGHLIGHT_STYLES, which the plugin
# only populates with its own defaults if unset).
[[ -f ~/.config/zsh/themes/catppuccin_mocha-zsh-syntax-highlighting.zsh ]] &&
  source ~/.config/zsh/themes/catppuccin_mocha-zsh-syntax-highlighting.zsh
[[ -f ~/.local/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh ]] &&
  source ~/.local/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh
