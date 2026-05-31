-- opencode.nvim — Neovim frontend for the OpenCode AI agent
-- https://github.com/sudo-tee/opencode.nvim
return {
  {
    "sudo-tee/opencode.nvim",
    lazy = true,
    cmd  = { "Opencode", "OpencodeToggle", "OpencodeSend" },
    keys = {
      { "<leader>ao", "<cmd>OpencodeToggle<cr>",            desc = "Toggle Opencode",         mode = "n" },
      { "<leader>as", "<cmd>OpencodeSend<cr>",              desc = "Send to Opencode",        mode = { "n", "v" } },
      { "<leader>an", "<cmd>Opencode new<cr>",              desc = "New Opencode session",    mode = "n" },
    },
    opts = {
      split_direction = "vertical",
      split_size      = 40,
    },
  },
}
