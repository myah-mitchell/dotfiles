-- Unified Ctrl+hjkl navigation between Neovim splits AND Zellij panes.
-- When at the edge of a Neovim window, calls `zellij action move-focus` to
-- move to the adjacent Zellij pane instead.
-- Pairs with zellij-autolock plugin in Zellij config, which switches Zellij
-- to built-in locked mode (full passthrough) when nvim is focused.
return {
  {
    "swaits/zellij-nav.nvim",
    lazy  = true,
    event = "VeryLazy",
    keys  = {
      { "<C-h>", "<cmd>ZellijNavigateLeftTab<cr>",  desc = "Navigate left (Neovim/Zellij)",  silent = true },
      { "<C-j>", "<cmd>ZellijNavigateDown<cr>",     desc = "Navigate down (Neovim/Zellij)",  silent = true },
      { "<C-k>", "<cmd>ZellijNavigateUp<cr>",       desc = "Navigate up (Neovim/Zellij)",    silent = true },
      { "<C-l>", "<cmd>ZellijNavigateRightTab<cr>", desc = "Navigate right (Neovim/Zellij)", silent = true },
    },
    opts = {},
  },
}
