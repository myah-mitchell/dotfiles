# config.nu — Nushell shell configuration
# Sourced after env.nu on every interactive session.

# ── Catppuccin Mocha theme ────────────────────────────────────────────────────
# source requires a parse-time literal path; bare ~ paths satisfy this without
# any version-specific $nu fields or const gymnastics.
source ~/.config/nushell/themes/catppuccin_mocha.nu

# ── Main config ───────────────────────────────────────────────────────────────
$env.config = {

  # ── History-related Settings ────────────────────────────────────────────────
  history: {
    max_size: 1_000_000 # Session has to be reloaded for this to take effect
    sync_on_enter: true # Enable to share history between multiple sessions, else you have to close the session to write history to file
    file_format: "sqlite" # "sqlite" or "plaintext" (sqlite required by atuin)
    isolation: false    # Controls history isolation between shell sessions
  }

  # ── Miscellaneous Settings ───────────────────────────────────────────────────
  show_banner: false    # Control the welcome banner at startup.
  rm: {
    always_trash: false # Controls default behavior of the rm command.
  }
  auto_cd_implicit: false # Gives precedence to auto-cd when command string is an existing directory path.

  # ── Commandline Editor Settings ─────────────────────────────────────────────
  edit_mode: vi         # Sets the editing behavior of Reedline.
  cursor_shape: {
    vi_insert: line     # Cursor shape when in vi insert mode.
    vi_normal: block    # Cursor shape when in vi normal mode.
    emacs:     line     # Cursor shape when in emacs edit mode.
  }

  # ── Completions Behavior ────────────────────────────────────────────────────
  show_hints: true      # Enable or disable inline hints for completions and history.
  completions: {
    algorithm: "prefix" # The algorithm used for matching completions.
    case_sensitive: false # Enable case-sensitive completions.
    quick: true         # Controls auto-selection of single completion results.
    partial: true       # sControls partial completion behavior.

    # ── External Completions ──────────────────────────────────────────────────
    external: {
      enable: true      # Enable searching for external commands on PATH
      max_results: 100  # Maximum external commands retrieved from PATH.
      #completer: null  # Custom closure for argument completions.
    }
  }

  # ── Terminal Integration ────────────────────────────────────────────────────
  use_kitty_protocol: false # Enable the Kitty keyboard enhancement protocol.
  shell_integration: { 
    osc2: true,         # Set terminal window/tab title to current directory and command.
    osc7: true,         # Report current directory to terminal using OSC 7.
    osc8: true,         # Generate clickable links in `ls` output.
    osc9_9: false,      # Alternative to OSC 7 for communicating current path.
    osc133: true        # Reports prompt location and command exit status to terminal.
    #bracketed_paste: true # Enable bracketed-paste mode.
  }
  use_ansi_coloring: true # Control ANSI coloring in Nushell output.

# ── Error Display Settings ────────────────────────────────────────────────────
  error_style: "fancy"  # One of "fancy", "plain", "short" or "nested"
  error_lines: 1        # Sets the number of context lines in the error output.  

# ── Table Display ─────────────────────────────────────────────────────────────
  table: {
    mode: rounded       # Visual border style for tables.
    index_mode: always  # When to show the index (#) column.
    show_empty: true    # Display placeholder for empty tables/lists.
    padding: { 
      left: 1,          # Spaces to pad on the left of cell values.
      right: 1          # Spaces to pad on the right of cell values.
    }
    trim: {
      methodology: wrapping # Rules for handling content when table exceeds terminal width.
      wrapping_try_keep_words: true # Avoid breaking words when wrapping.
      truncating_suffix: "..." # A suffix used by the 'truncating' methodology
    }
  }

  # ── Miscellaneous Display ───────────────────────────────────────────────────
  render_right_prompt_on_last_line: false # Right prompt position with multi-line left prompt.
  ls: {
    use_ls_colors: true # Apply LS_COLORS to filenames in `ls` output.
    clickable_links: true # Generate clickable links in `ls` output.
  }

  # ── Hooks ───────────────────────────────────────────────────────────────────
  hooks: {
    pre_prompt: [{||
      null  # replace with source code to run before the prompt is shown
    }]
    pre_execution: [{||
      null  # replace with source code to run before the repl input is run
    }]
    env_change: {
      PWD: [{|before, after|
        null  # replace with source code to run if the PWD environment is different since the last repl input
      }]
    }
    display_output: {||
      if (term size).columns >= 100 { table -e } else { table }
    }
  }
  
  # ── Keybindings ─────────────────────────────────────────────────────────────
  keybindings: [
    # Ctrl+R — open atuin history (overrides default history menu)
    {
      name:     atuin_history
      modifier: control
      keycode:  char_r
      mode:     [emacs, vi_normal, vi_insert]
      event:    { send: ExecuteHostCommand, cmd: "atuin search --interactive" }
    }
    # Ctrl+F — fzf file picker, insert path
    {
      name:     fzf_file
      modifier: control
      keycode:  char_f
      mode:     [emacs, vi_normal, vi_insert]
      event:    {
        send: ExecuteHostCommand
        cmd:  "commandline edit --insert (fzf --popup --prompt 'File> ' | str trim)"
      }
    }
  ]
  
  # ── Abbreviations ───────────────────────────────────────────────────────────
  #l: "ls -alt | table --icons"

  # ── Menus ───────────────────────────────────────────────────────────────────
  menus: [
    {
      name: completion_menu
      only_buffer_difference: false
      marker: "| "
      type: { layout: columnar, columns: 4, col_width: 20, col_padding: 2 }
      style: {
        text:          green
        selected_text: { attr: r }
        description_text: yellow
        match_text:    { attr: u }
        selected_match_text: { attr: ur }
      }
    }
    {
      name: history_menu
      only_buffer_difference: true
      marker: "? "
      type: { layout: list, page_size: 10 }
      style: { text: green, selected_text: { attr: r }, description_text: yellow }
    }
    {
      name: help_menu
      only_buffer_difference: true
      marker: "? "
      type: {
        layout: description
        columns: 4
        col_width: 20   # Optional value. If missing all the screen width is used to calculate column width
        col_padding: 2
        selection_rows: 4
        description_rows: 10
      }
      style: {
        text: green
        selected_text: green_reverse
        description_text: yellow
      }
    }

  ]

  # ── Themes/Colors and Syntax Highlighting ───────────────────────────────────
  color_config: $theme # Using a theme from the standard library

  # ── Environment Variables ───────────────────────────────────────────────────

  # ── Plugin Settings ─────────────────────────────────────────────────────────
  plugins: {
    highlight: {
      custom_themes: ~/.config/nushell/themes
      theme: catppuccin_mocha
    }
  }
}

# ── Tool integrations ─────────────────────────────────────────────────────────

# zoxide — frecency-based cd
source ~/.local/share/zoxide/init.nu

# atuin — shell history
source ~/.local/share/atuin/init.nu

# starship — prompt
source ~/.cache/starship/init.nu

# carapace — argument completions
source ~/.cache/carapace/init.nu

# ── Zellij auto-start ─────────────────────────────────────────────────────────
# Only start Zellij if we're not already inside it and it's an interactive session
def --env zellij_autostart [] {
  if not ("ZELLIJ" in $env) {
    if ($env.ZELLIJ_AUTO_ATTACH? == "true") {
      zellij attach --create
    } else {
      zellij
    }
    if ($env.ZELLIJ_AUTO_EXIT? == "false") {
      return
    }
    exit
  }
}

# Only autostart in interactive sessions (not scripts, not SSH without a tty)
if $nu.is-interactive {
  zellij_autostart
}

# ── Yazi wrapper — changes directory on exit ──────────────────────────────────
def --env y [...args: string] {
  let tmp = (mktemp -t "yazi-cwd.XXXXXX")
  yazi ...$args --cwd-file $tmp
  let cwd = (open $tmp | str trim)
  if ($cwd | is-not-empty) and ($cwd != $env.PWD) {
    cd $cwd
  }
  ^rm -f $tmp
}

# ── sudo — preserve user PATH so ~/.local/bin tools are visible ───────────────
# sudo strips the environment by default; this wrapper re-injects PATH so that
# `sudo bat`, `sudo rg`, etc. find the tools installed in ~/.local/bin.
def --wrapped sudo [...args: string] {
  ^sudo env $"PATH=($env.PATH | str join ':')" ...$args
}

# ── sudo!! — re-run the last command with sudo (bash `sudo !!` equivalent) ────
# Note: type `sudo!!` (no space) — `sudo !!` treats !! as a literal command name.
def "sudo!!" [] {
  let cmd = (history | get command | last)
  ^sudo env $"PATH=($env.PATH | str join ':')" nu -c $cmd
}

# ── nr — call native system binary for any command ───────────────────────────
# Usage: nr ls -la     nr du -sh .     nr rm -rf /tmp/test
def nr [tool: string, ...args: string] {
  run-external $"/usr/bin/($tool)" ...$args
}