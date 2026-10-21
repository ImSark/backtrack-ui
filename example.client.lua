-- Requires an environment that supports game:HttpGet and loadstring.
local BacktrackUI = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/ImSark/backtrack-ui/refs/heads/main/backtrack_ui.lua"
))()

local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
local showCompanionPanels = viewport.X >= 1858 and viewport.Y >= 866

local menu = BacktrackUI.new({
	title = "Backtrack",
	name = "BacktrackUI",
	anchorPoint = showCompanionPanels and Vector2.zero or Vector2.new(0.5, 0.5),
	position = showCompanionPanels and UDim2.new(0.5, -398, 0.5, -433) or UDim2.fromScale(0.5, 0.5),
	toggleKey = Enum.KeyCode.RightShift,
	images = {
		-- Upload the PNGs in assets/roblox to Roblox, then paste their asset IDs here.
		-- main = "rbxassetid://YOUR_MAIN_ICON_ID",
		-- style = "rbxassetid://YOUR_STYLE_ICON_ID",
		-- configurations = "rbxassetid://YOUR_CONFIGURATIONS_ICON_ID",
		-- playerlist = "rbxassetid://YOUR_PLAYERLIST_ICON_ID",
		-- output = "rbxassetid://YOUR_OUTPUT_ICON_ID",
		-- glow4 = "rbxassetid://YOUR_GLOW4_IMAGE_ID",
	},
})

local general = menu:AddTab("General", "main")
local generalLeft = general:Column()
local generalRight = general:Column()

local controls = generalLeft:AddSection("Controls")
local enabled = controls:Toggle({
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

local tools = menu:AddTab("Tools", "output")
local toolsColumn = tools:Column()
local outputSection = toolsColumn:AddSection("Output")
local output = outputSection:Output({ height = 180 })
output:Add("Library loaded", "INFO")
output:Add("Callbacks are owned by the host script", "READY")

local settings = menu:AddTab("Settings", "style")
local settingsSection = settings:Column():AddSection("Appearance")
settingsSection:Label({ name = "Accent", text = "#FF627F" })
settingsSection:Button({
	name = "Restore accent",
	callback = function()
		menu:SetTheme({ accent = Color3.fromRGB(255, 98, 127), glow = Color3.fromRGB(255, 98, 127) })
	end,
})

local configs = menu:AddTab("Configs", "configurations")
local configSection = configs:Column():AddSection("Configurations")
configSection:Textbox({ name = "Name", flag = "config_name", placeholder = "Type here...", max = 30 })
configSection:Button({ name = "Save", callback = function() menu:Notify("Save from your own callback", 3) end })
configSection:Button({ name = "Load", callback = function() menu:Notify("Load from your own callback", 3) end })

if showCompanionPanels then
	local style = menu:CreatePanel("Style", {
		name = "StylePanel",
		image = "style",
		size = UDim2.fromOffset(394, 631),
		position = UDim2.new(0.5, 208, 0.5, -433),
	})
	style:AddLabel("Theme")
	style:AddLabel("Accent: #FF627F")
	style:AddLabel("Outline: #0A0A0A")
	style:AddLabel("Inline: #222222")
	style:AddButton("Restore theme", function()
		menu:SetTheme({
			accent = Color3.fromRGB(255, 98, 127),
			outline = Color3.fromRGB(10, 10, 10),
			inline = Color3.fromRGB(34, 34, 34),
			contrastTop = Color3.fromRGB(41, 41, 55),
			contrastBottom = Color3.fromRGB(35, 35, 47),
		})
	end)

	local configurationPanel = menu:CreatePanel("Configurations", {
		name = "ConfigurationsPanel",
		image = "configurations",
		size = UDim2.fromOffset(324, 438),
		position = UDim2.new(0.5, 208, 0.5, -433),
	})
	configurationPanel:AddLabel("Active configuration")
	configurationPanel:AddList({ "Default", "Example" })
	configurationPanel:AddButton("Create", function() menu:Notify("Use your own save callback", 3) end)
	configurationPanel:AddButton("Load", function() menu:Notify("Use your own load callback", 3) end)
	configurationPanel:SetVisible(false)

	local players = menu:CreatePanel("Playerlist", {
		name = "PlayerlistPanel",
		image = "playerlist",
		size = UDim2.fromOffset(529, 445),
		position = UDim2.new(0.5, -929, 0.5, -433),
	})
	players:AddLabel("Players")
	players:AddList({ "Local player", "Example player", "Another player" })

	local standaloneOutput = menu:CreatePanel("Output", {
		name = "OutputPanel",
		image = "output",
		size = UDim2.fromOffset(529, 267),
		position = UDim2.new(0.5, -929, 0.5, 14),
	})
	standaloneOutput:AddLabel("[INFO] Library loaded")
	standaloneOutput:AddLabel("[READY] UI callbacks are available")
	standaloneOutput:AddButton("Clear Output", function()
		for _, child in ipairs(standaloneOutput.Frame:GetDescendants()) do
			if child:IsA("TextLabel") and (child.Text:find("%[INFO%]") or child.Text:find("%[READY%]")) then child:Destroy() end
		end
	end)
end

menu:CreateDock({ icon = "main" })
menu:CreateWatermark("backtrack.tech")
