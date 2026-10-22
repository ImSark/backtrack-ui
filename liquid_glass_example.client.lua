-- Standalone Liquid Glass UI example for executors supporting HttpGet/loadstring.
local libraryUrl = "https://raw.githubusercontent.com/ImSark/backtrack-ui/main/liquid_glass_ui.lua"
local cacheBuster = tostring(math.floor(os.clock() * 1000000))
local LiquidGlassUI = loadstring(game:HttpGet(libraryUrl .. "?t=" .. cacheBuster))()

local ui = LiquidGlassUI.new({
	title = "Liquid Glass",
	subtitle = "A clear view of your workspace",
	footer = "LIQUID GLASS  ·  INTERACTIVE DEMO",
	toggleKey = Enum.KeyCode.RightShift,
	size = UDim2.fromOffset(720, 500),
})

local home = ui:AddTab({ name = "Overview", iconText = "◈" })
local appearance = ui:AddTab({ name = "Appearance", iconText = "◉" })
local tools = ui:AddTab({ name = "Tools", iconText = "⌘" })

local status = home:AddSection("Welcome")
status:Label({ name = "Liquid Glass UI", textSize = 14 })
status:Label("Translucent surfaces, soft reflections, and rounded controls.")
status:Button({
	name = "Show notification",
	callback = function()
		ui:Notify("Your glass interface is ready.", 3, "success")
	end,
})

local controls = home:AddSection("Controls")
controls:Toggle({
	name = "Enable feature",
	default = true,
	callback = function(enabled)
		ui:Notify(enabled and "Feature enabled" or "Feature disabled", 2)
	end,
})
controls:Slider({ name = "Intensity", min = 0, max = 100, step = 5, default = 45, suffix = "%" })
controls:Dropdown({ name = "Quality", items = { "Low", "Balanced", "High" }, default = "Balanced" })

local theme = appearance:AddSection("Glass palette")
theme:Label("Update the accent while the window is open.")
theme:Colorpicker({
	name = "Accent",
	color = ui.Theme.accent,
	callback = function(color)
		ui:SetTheme({ accent = color, accentSecondary = color:Lerp(Color3.new(1, 1, 1), 0.35) })
	end,
})
theme:Colorpicker({
	name = "Glass tint",
	color = ui.Theme.glass,
	callback = function(color)
		ui:SetTheme({ glass = color })
	end,
})

local toolsSection = tools:AddSection("Utilities")
toolsSection:Textbox({ name = "Display name", default = "Operator", callback = function(value) print("Name:", value) end })
toolsSection:Keybind({ name = "Demo shortcut", default = Enum.KeyCode.K, callback = function(key) print("Bound to:", key.Name) end })
toolsSection:Button({ name = "Minimize window", callback = function() ui:SetMinimized(true) end })
toolsSection:Button({ name = "Restore theme", callback = function() ui:SetTheme(LiquidGlassUI.Theme) end })

return ui
