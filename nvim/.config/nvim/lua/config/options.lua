local opt = vim.opt

-- Line numbers
opt.number         = true
opt.relativenumber = true

-- Indentation
opt.tabstop        = 2
opt.shiftwidth     = 2
opt.expandtab      = true
opt.smartindent    = true

-- Search
opt.ignorecase     = true
opt.smartcase      = true
opt.hlsearch       = true
opt.incsearch      = true

-- Display
opt.scrolloff      = 8
opt.sidescrolloff  = 8
opt.wrap           = false
opt.cursorline     = true
opt.signcolumn     = "yes"
-- No bottom statusline: lualine is disabled (see plugins/lualine.lua); the
-- Zellij zjstatus bar + incline.nvim cover mode/git/filename instead.
opt.laststatus     = 0
opt.colorcolumn    = "120"
opt.list           = true
opt.listchars      = { tab = "→ ", trail = "·", nbsp = "␣" }

-- Splits open to the right and below (matches hjkl mental model)
opt.splitright     = true
opt.splitbelow     = true

-- System clipboard — required for WSL2 clipboard integration
opt.clipboard      = "unnamedplus"

-- Mouse
opt.mouse          = "a"

-- Colors — full 24-bit color
opt.termguicolors  = true

-- Undo
opt.undofile       = true
opt.undolevels     = 10000

-- Completion
opt.pumheight      = 10
opt.completeopt    = "menu,menuone,noselect"

-- Fold (using treesitter)
opt.foldmethod     = "expr"
opt.foldexpr       = "nvim_treesitter#foldexpr()"
opt.foldlevel      = 99

-- Performance
opt.updatetime     = 200
opt.timeoutlen     = 300
opt.ttimeoutlen    = 0

-- Misc
opt.confirm        = true
opt.swapfile       = false
opt.backup         = false
opt.writebackup    = false
opt.fileencoding   = "utf-8"

-- Set leader to space (LazyVim default; backtick is Zellij's prefix)
vim.g.mapleader      = " "
vim.g.maplocalleader = "\\"
