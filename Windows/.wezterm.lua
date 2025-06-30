local wezterm = require "wezterm"

local config = wezterm.config_builder()

config.default_prog = { 'powershell.exe', '-NoLogo' }
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "RESIZE"
config.background = {
	{
		source = {
			File = "C:/Users/leon.faerber/Downloads/Black.png"
		},
		width = "100%",
		repeat_y = "NoRepeat",
		repeat_x = "NoRepeat",
		height = "100%",
		vertical_align = "Middle",
		opacity = 0.90
	}
}

return config
