-- Enable full border
require("full-border"):setup()

-- Enable git support
require("git"):setup({
	-- Order of status signs showing in the linemode
	order = 1500,
})

-- Enable Starship
require("starship"):setup()

-- Enable Yatline
local catppuccin_theme = require("yatline-catppuccin"):setup("mocha")
require("yatline"):setup({
	theme = catppuccin_theme,
})

-- Enable yatline Git
require("yatline-githead"):setup({
	theme = catppuccin_theme,
})

Status:children_add(function()
	local h = cx.active.current.hovered
	if not h or ya.target_family() ~= "unix" then
		return ""
	end

	return ui.Line({
		ui.Span(ya.user_name(h.cha.uid) or tostring(h.cha.uid)):fg("magenta"),
		":",
		ui.Span(ya.group_name(h.cha.gid) or tostring(h.cha.gid)):fg("magenta"),
		" ",
	})
end, 500, Status.RIGHT)
