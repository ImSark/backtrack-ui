-- Standalone Liquid Glass UI example for executors supporting HttpGet/loadstring.
local libraryUrl = "https://raw.githubusercontent.com/ImSark/backtrack-ui/main/liquid_glass_ui.lua"
local cacheBuster = tostring(math.floor(os.clock() * 1000000))
local LiquidGlassUI = loadstring(game:HttpGet(libraryUrl .. "?t=" .. cacheBuster))()
local materialStatus, transparencySlider

local ui = LiquidGlassUI.new({
	title = "Liquid Glass",
	subtitle = "A lighter way to stay in control",
	footer = "YOUR WORKSPACE, IN FOCUS",
	toggleKey = Enum.KeyCode.RightShift,
	size = UDim2.fromOffset(760, 580),
	blur = 0,
	replaceExisting = true,
	onRefractionReady = function(_, window)
		if materialStatus then materialStatus:Set("Material: refractive glass (high graphics required)") end
		if transparencySlider then transparencySlider:Set(math.floor(window.Theme.glassTransparency * 100), true) end
	end,
	onRefractionError = function(_, window)
		if materialStatus then materialStatus:Set("Material: translucent fallback (see console)") end
		window:Notify("Glass refraction could not load. See the executor console for details.", 6, "error")
	end,
})

local home = ui:AddTab({ name = "Overview", iconText = "◈" })
local appearance = ui:AddTab({ name = "Appearance", iconText = "◉" })
local tools = ui:AddTab({ name = "Tools", iconText = "⌘" })

local status = home:AddSection("Welcome")
status:Label({ name = "Liquid Glass UI", textSize = 14 })
status:Label("Clear surfaces, soft reflections, and floating controls.")
materialStatus = status:Label(ui.RefractionStatus == "ready" and "Material: refractive glass (high graphics required)" or "Material: " .. ui.RefractionStatus)
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
theme:Label("Make the material your own.")
transparencySlider = theme:Slider({
	name = "Glass transparency", min = 15, max = 95, default = math.floor(ui.Theme.glassTransparency * 100), suffix = "%",
	callback = function(value) ui:SetTheme({ glassTransparency = value / 100 }) end,
})
theme:Slider({
	name = "Backdrop blur", min = 0, max = 24, default = 0,
	callback = function(value) ui:SetBlur(value) end,
})
theme:Slider({
	name = "Refraction strength", min = 1.1, max = 6, step = 0.1, default = 3,
	callback = function(value) ui:SetRefractionStrength(value) end,
})
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
toolsSection:Button({
	name = "Restore theme",
	callback = function()
		local defaults = {}
		for key, value in pairs(LiquidGlassUI.Theme) do defaults[key] = value end
		if ui.RefractionStatus == "ready" then defaults.glassTransparency = 0.84 end
		ui:SetTheme(defaults)
		transparencySlider:Set(math.floor(ui.Theme.glassTransparency * 100), true)
	end,
})

return ui
