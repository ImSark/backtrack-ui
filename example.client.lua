-- Requires an environment that supports game:HttpGet and loadstring.
local BacktrackUI = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/ImSark/backtrack-ui/refs/heads/main/backtrack_ui.lua"
	))()

local menu = BacktrackUI.new({
	title = "Backtrack UI Example",
	toggleKey = Enum.KeyCode.RightShift,
	theme = {
		accent = Color3.fromRGB(255, 98, 127),
	},
})

local general = menu:AddTab("General")
local generalLeft = general:Column()
local generalRight = general:Column()

local toggles = generalLeft:AddSection("Controls")
local enabled = toggles:Toggle({
	name = "Enabled",
	flag = "enabled",
	default = true,
	callback = function(value)
		print("Enabled:", value)
	end,
})
enabled:Keybind({
	name = "Enabled bind",
	flag = "enabled_bind",
	mode = "Toggle",
	callback = function(value)
		print("Bind active:", value)
	end,
})
enabled:Colorpicker({
	name = "Enabled color",
	flag = "enabled_color",
	color = Color3.fromRGB(255, 98, 127),
	callback = function(color, alpha)
		print("Color:", color, "opacity:", alpha)
	end,
})

local values = generalLeft:AddSection("Values")
values:Slider({
	name = "Strength",
	flag = "strength",
	min = 0,
	max = 100,
	step = 5,
	default = 30,
	suffix = "%",
})
values:Textbox({
	name = "Label",
	flag = "label",
	default = "Sample",
	placeholder = "Enter a label",
	max = 32,
})

local choices = generalRight:AddSection("Choices")
choices:Dropdown({
	name = "Single choice",
	flag = "single_choice",
	items = { "First", "Second", "Third" },
	default = "First",
})
choices:Dropdown({
	name = "Multiple choice",
	flag = "multiple_choice",
	items = { "Alpha", "Beta", "Gamma" },
	multi = true,
	default = { "Alpha" },
})
choices:Configuration({ name = "Extra options" }, function(section)
	section:Toggle({ name = "Show watermark", flag = "show_watermark", default = true })
	section:Button({ name = "Send notice", callback = function() menu:Notify("Hello from the UI library.", 3, "success") end })
end)

local tools = menu:AddTab("Tools")
local toolsColumn = tools:Column()
local outputSection = toolsColumn:AddSection("Output")
local output = outputSection:Output({ height = 180 })
output:Add("Library loaded", "INFO")
output:Add("Callbacks are owned by the host script", "READY", menu.Theme.positive)

menu:CreateWatermark("Backtrack UI")
