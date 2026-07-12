-- claudecode.nvim — Claude Code sidebar for Neovim (replaces the old OpenCode setup).
-- Runs the `claude` CLI in a snacks terminal split and connects over the same
-- WebSocket/MCP protocol as the VSCode/JetBrains extensions, so the current buffer,
-- visual selections, and diffs flow into the session and diffs can be applied back.
-- `claude` is on $PATH (~/.local/bin/claude), so no terminal_cmd override is needed.
-- https://github.com/coder/claudecode.nvim
return {
  "coder/claudecode.nvim",
  dependencies = { "folke/snacks.nvim" },
  cmd = {
    "ClaudeCode", "ClaudeCodeFocus", "ClaudeCodeSend", "ClaudeCodeAdd",
    "ClaudeCodeTreeAdd", "ClaudeCodeSelectModel", "ClaudeCodeDiffAccept",
    "ClaudeCodeDiffDeny",
  },
  opts = {
    terminal = {
      split_side             = "right", -- matches splitright mental model
      split_width_percentage = 0.30,
      provider               = "snacks",
    },
  },
  keys = {
    { "<leader>a",  nil,                              desc = "AI/Claude Code" },
    { "<leader>ac", "<cmd>ClaudeCode<cr>",            desc = "Toggle Claude" },
    { "<leader>af", "<cmd>ClaudeCodeFocus<cr>",       desc = "Focus Claude" },
    { "<leader>ar", "<cmd>ClaudeCode --resume<cr>",   desc = "Resume Claude session" },
    { "<leader>aC", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude conversation" },
    { "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
    { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>",       desc = "Add current buffer to context" },
    { "<leader>as", "<cmd>ClaudeCodeSend<cr>",        mode = "v", desc = "Send selection to Claude" },
    {
      "<leader>as",
      "<cmd>ClaudeCodeTreeAdd<cr>",
      desc = "Add file to Claude context",
      -- snacks_picker_list is the snacks explorer sidebar filetype
      ft   = { "neo-tree", "oil", "minifiles", "netrw", "snacks_picker_list" },
    },
    { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>",  desc = "Accept Claude diff" },
    { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>",    desc = "Deny Claude diff" },
  },
}
