return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      vim.env.CC = "gcc"
      require("nvim-treesitter.install").compilers = { "gcc", "clang" }
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "regex" })
      return opts
    end,
  },
}
