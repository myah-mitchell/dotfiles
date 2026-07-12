-- incline.nvim — floating label in the top-right of each split.
-- dropbar (see dropbar.lua) owns the top-left winbar with the folder/file/symbol
-- path, so incline does NOT repeat the filename — it shows *file info* instead:
-- diagnostics + this file's git diff (per-buffer, not in zjstatus) then filetype,
-- line count, size, and indent style. Nothing here duplicates the zjstatus bar.
return {
  "b0o/incline.nvim",
  event = "VeryLazy",
  dependencies = { "catppuccin/nvim", "nvim-tree/nvim-web-devicons" },
  config = function()
    local mocha = require("catppuccin.palettes").get_palette("mocha")
    local uv = vim.uv or vim.loop

    -- Error/Warn/Info/Hint counts for the buffer, using LazyVim's diagnostic icons.
    local function diagnostics(buf)
      local out = {}
      local icons = { Error = " ", Warn = " ", Info = " ", Hint = " " }
      for _, sev in ipairs({ "Error", "Warn", "Info", "Hint" }) do
        local n = #vim.diagnostic.get(buf, { severity = vim.diagnostic.severity[sev:upper()] })
        if n > 0 then
          table.insert(out, { icons[sev] .. n .. " ", group = "DiagnosticSign" .. sev })
        end
      end
      return out
    end

    -- Per-file git diff stats from gitsigns (added / changed / removed).
    local function gitdiff(buf)
      local out = {}
      local sd = vim.b[buf].gitsigns_status_dict
      if sd then
        local parts = {
          { sd.added, " ", "GitSignsAdd" },
          { sd.changed, " ", "GitSignsChange" },
          { sd.removed, " ", "GitSignsDelete" },
        }
        for _, p in ipairs(parts) do
          if p[1] and p[1] > 0 then
            table.insert(out, { p[2] .. p[1] .. " ", group = p[3] })
          end
        end
      end
      return out
    end

    local function human_size(bytes)
      local units = { "B", "K", "M", "G" }
      local i = 1
      while bytes >= 1024 and i < #units do
        bytes = bytes / 1024
        i = i + 1
      end
      return i == 1 and string.format("%d%s", bytes, units[i]) or string.format("%.1f%s", bytes, units[i])
    end

    require("incline").setup({
      hide = { cursorline = true },
      window = {
        margin = { vertical = 0, horizontal = 1 },
        padding = 1,
        placement = { horizontal = "right", vertical = "top" },
      },
      render = function(props)
        local buf = props.buf
        local bo = vim.bo[buf]
        local name = vim.api.nvim_buf_get_name(buf)
        local dim = props.focused and mocha.overlay1 or mocha.overlay0
        local accent = props.focused and mocha.text or mocha.overlay1

        local icon, color = require("nvim-web-devicons").get_icon_color(
          name == "" and "" or vim.fn.fnamemodify(name, ":t")
        )
        local lines = vim.api.nvim_buf_line_count(buf)
        local indent = bo.expandtab and ("␣" .. bo.shiftwidth) or ("⇥" .. bo.tabstop)

        local res = {}
        vim.list_extend(res, diagnostics(buf))
        vim.list_extend(res, gitdiff(buf))
        table.insert(res, icon and { icon .. " ", guifg = color } or "")
        table.insert(res, { bo.filetype ~= "" and bo.filetype or "text", gui = "bold", guifg = accent })
        table.insert(res, { "  " .. lines .. "L", guifg = dim })
        if name ~= "" then
          local st = uv.fs_stat(name)
          if st then
            table.insert(res, { "  " .. human_size(st.size), guifg = dim })
          end
        end
        table.insert(res, { "  " .. indent, guifg = dim })
        -- surface only non-default encoding / line-endings
        if bo.fileencoding ~= "" and bo.fileencoding ~= "utf-8" then
          table.insert(res, { "  " .. bo.fileencoding, guifg = mocha.yellow })
        end
        if bo.fileformat ~= "unix" then
          table.insert(res, { "  " .. bo.fileformat, guifg = mocha.yellow })
        end
        table.insert(res, (bo.readonly or not bo.modifiable) and { "  ", guifg = mocha.red } or "")
        table.insert(res, bo.modified and { " ●", guifg = mocha.peach } or "")
        return res
      end,
    })
  end,
}
