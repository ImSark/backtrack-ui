-- Requires an environment that supports game:HttpGet and loadstring.
-- This is a visual demo of the original menu layout. All callbacks are inert
-- examples; the library does not implement the source script's game behavior.
local BacktrackUI = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/ImSark/backtrack-ui/refs/heads/main/backtrack_ui.lua"
))()

local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
local showCompanionPanels = viewport.X >= 1858 and viewport.Y >= 866

-- Executors with file APIs can load the original pixel icons and glow directly
-- from this public repo. Other environments keep the built-in text fallback.
local images = {}
local fontFace
local customAsset = getcustomasset or getsynasset
if type(writefile) == "function" and type(customAsset) == "function" then
	local folder = "backtrack_ui_assets"
	if type(isfolder) == "function" and type(makefolder) == "function" then
		local ok, exists = pcall(isfolder, folder)
		if not ok or not exists then pcall(makefolder, folder) end
	end

	for _, name in ipairs({ "main", "style", "configurations", "playerlist", "output", "scroll", "glow4" }) do
		local path = folder .. "/" .. name .. ".png"
		local exists = false
		if type(isfile) == "function" then
			local ok, result = pcall(isfile, path)
			exists = ok and result == true
		end
		if not exists then
			local ok, bytes = pcall(function()
				return game:HttpGet("https://raw.githubusercontent.com/ImSark/backtrack-ui/refs/heads/main/assets/roblox/" .. name .. ".png")
			end)
			if ok and type(bytes) == "string" and #bytes > 0 then
				pcall(writefile, path, bytes)
			end
		end
		local ok, content = pcall(customAsset, path)
		if ok and type(content) == "string" then images[name] = content end
	end

	-- The source uses its bundled bitmap Tahoma font. Executors can register
	-- the same font with a local .font descriptor for FontFace.
	local fontPath = folder .. "/fs-tahoma-8px.ttf"
	local fontExists = false
	if type(isfile) == "function" then
		local ok, result = pcall(isfile, fontPath)
		fontExists = ok and result == true
	end
	if not fontExists then
		local ok, bytes = pcall(function()
			return game:HttpGet("https://github.com/backtrack-tech/backtrack.tech/raw/main/fonts/fs-tahoma-8px.ttf")
		end)
		if ok and type(bytes) == "string" and #bytes > 0 then pcall(writefile, fontPath, bytes) end
	end
	local fontAssetOk, fontAsset = pcall(customAsset, fontPath)
	if fontAssetOk and type(fontAsset) == "string" then
		local descriptorPath = folder .. "/Tahoma.font"
		local http = game:GetService("HttpService")
		local descriptor = http:JSONEncode({
			name = "BacktrackTahoma",
			faces = { { name = "Normal", weight = 400, style = "Normal", assetId = fontAsset } },
		})
		local descriptorWritten = pcall(writefile, descriptorPath, descriptor)
		if descriptorWritten then
			local faceAssetOk, faceAsset = pcall(customAsset, descriptorPath)
			if faceAssetOk and type(faceAsset) == "string" then
				local faceOk, registeredFace = pcall(function()
					return Font.new(faceAsset, Enum.FontWeight.Regular, Enum.FontStyle.Normal)
				end)
				if faceOk then fontFace = registeredFace end
			end
		end
	end
end

local menu = BacktrackUI.new({
	title = "backtrack.tech - " .. os.date("%b %d %Y"),
	name = "BacktrackUI",
	anchorPoint = showCompanionPanels and Vector2.zero or Vector2.new(0.5, 0.5),
	position = showCompanionPanels and UDim2.new(0.5, -398, 0.5, -433) or UDim2.fromScale(0.5, 0.5),
	toggleKey = Enum.KeyCode.End,
	images = images,
	theme = fontFace and { fontFace = fontFace } or nil,
})

local function previewToggle(section, name, default)
	return section:Toggle({
		name = name,
		flag = name:lower():gsub("[^%w]+", "_"),
		default = default == true,
		callback = function(value)
			print(name .. ":", value)
		end,
	})
end

local function previewSlider(section, name, min, max, default, suffix)
	return section:Slider({
		name = name,
		flag = name:lower():gsub("[^%w]+", "_"),
		min = min,
		max = max,
		default = default,
		step = 1,
		suffix = suffix or "",
	})
end

-- These are the source menu's four tabs, flex columns, and section tabs. The
-- displayed controls only demonstrate the UI library.
local combat = menu:AddTab("Combat")
local combatLeft = combat:Column()
local combatAim, combatVisualization = combatLeft:MultiSection({ names = { "Aiming", "Visualization" } })
local combatRight = combat:Column()
local combatOther = combatRight:AddSection("Other")
local weaponMods = combatRight:Column():AddSection("Weapon Modifications")

local silentAim = previewToggle(combatAim, "Silent Aim")
silentAim:Keybind({ name = "Silent Aim", flag = "silent_aim_bind", mode = "Hold" })
silentAim:Colorpicker({ name = "Aim Color", flag = "aim_color", color = Color3.fromRGB(255, 98, 127) })
local aimAssist = previewToggle(combatAim, "Aim Assist")
aimAssist:Keybind({ name = "Aim Assist", flag = "aim_assist_bind", mode = "Hold" })
previewToggle(combatAim, "Auto Shoot")
previewToggle(combatAim, "Wall Check")
previewToggle(combatAim, "Dead Check")
previewToggle(combatAim, "Distance Check")
previewToggle(combatAim, "Use FOV", true)
previewSlider(combatAim, "FOV Radius", 1, 1250, 150)
combatAim:Dropdown({ name = "Target Part", flag = "target_part", items = { "Head", "Upper Torso", "HumanoidRootPart" }, default = "Head" })

previewToggle(combatVisualization, "Enable FOV")
combatVisualization:Colorpicker({ name = "Gradient Color Left", flag = "fov_gradient_left", color = Color3.fromRGB(255, 98, 127) })
combatVisualization:Colorpicker({ name = "Gradient Color Right", flag = "fov_gradient_right", color = Color3.fromRGB(203, 79, 104) })
previewToggle(combatVisualization, "Filled")
previewToggle(combatVisualization, "Glow")
previewToggle(combatVisualization, "Spin")
previewSlider(combatVisualization, "Spin Speed", -5, 5, 1)
previewToggle(combatVisualization, "Enable Snapline")

combatOther:Dropdown({
	name = "Target Sorting Type",
	flag = "target_sorting",
	items = { "Closest To Mouse", "Distance" },
	default = "Closest To Mouse",
})
previewToggle(combatOther, "Target Players", true)
previewToggle(combatOther, "Target AI", true)
previewToggle(combatOther, "Prioritize Enemies", true)
combatOther:Dropdown({ name = "Priority", flag = "priority", items = { "Enemy", "Neutral", "Friendly" }, default = "Neutral" })

previewToggle(weaponMods, "No Recoil")
previewToggle(weaponMods, "No Spread")
previewToggle(weaponMods, "Unlock Firemodes")
previewToggle(weaponMods, "Double Tap")
previewToggle(weaponMods, "Rapid Fire")
previewSlider(weaponMods, "Fire Rate", 1, 100, 1, "%")
previewToggle(weaponMods, "Rapid Knife")
previewSlider(weaponMods, "Swing Rate", 1, 100, 1, "%")

local playersTab = menu:AddTab("Players")
local playerSections = playersTab:Column()
local playerESP, npcESP, otherESP = playerSections:MultiSection({ names = { "Players", "NPC", "Other" } })
local playerSide = playersTab:Column()
local preview = playerSide:AddSection("ESP Preview")
local playerOptions = playerSide:Column():AddSection("Options")
preview:Label({ name = "Player ESP Preview", color = Color3.fromRGB(224, 224, 224) })
preview:Label({ name = "Name    Distance    Weapon", color = Color3.fromRGB(160, 160, 166) })
previewToggle(playerESP, "ESP Enabled")
previewToggle(playerESP, "Bounding Box")
previewToggle(playerESP, "Name")
previewToggle(playerESP, "Distance")
previewToggle(playerESP, "Health Bar")
previewToggle(playerESP, "Weapon")
previewToggle(npcESP, "ESP Enabled")
previewToggle(npcESP, "Bounding Box")
previewToggle(npcESP, "Name")
previewToggle(npcESP, "Distance")
previewToggle(otherESP, "ESP Enabled")
previewToggle(otherESP, "Exits")
previewToggle(otherESP, "Items")
previewToggle(otherESP, "Helicopters")
playerOptions:Dropdown({ name = "Bounding Type", items = { "Static", "Dynamic" }, default = "Static" })
previewSlider(playerOptions, "Dynamic Padding", 0.7, 2, 1)
previewSlider(playerOptions, "Static Width", 2, 4, 3.6)
previewSlider(playerOptions, "Static Height", 5, 5.5, 5)
previewToggle(playerOptions, "Display Measurement Unit", true)
playerOptions:Dropdown({ name = "Measurement Unit", items = { "Studs", "Meters" }, default = "Meters" })

local misc = menu:AddTab("Misc")
local movement, exploits = misc:Column():MultiSection({ names = { "Movement", "Exploits" } })
local miscSide = misc:Column()
local localOptions, chat = miscSide:MultiSection({ names = { "Local", "Chat" } })
local replication, replicationVisuals = miscSide:Column():MultiSection({ names = { "Replication", "Visualization" } })
previewToggle(movement, "Flyhack")
previewSlider(movement, "Horizontal Speed", 1, 100, 16)
previewSlider(movement, "Vertical Speed", 1, 100, 16)
previewToggle(movement, "Infinite Stamina")
previewToggle(exploits, "Long Jump")
previewToggle(exploits, "Speed")
previewToggle(localOptions, "Third Person")
previewToggle(localOptions, "Custom FOV")
previewSlider(localOptions, "Field of View", 60, 120, 90, "°")
previewToggle(chat, "Chat Spammer")
previewToggle(chat, "Chat Filter Bypass")
previewToggle(replication, "Name Changer")
previewToggle(replication, "Fake Lag")
previewToggle(replicationVisuals, "Show Replication")
previewToggle(replicationVisuals, "Show Chams")

local visuals = menu:AddTab("Visuals")
local notifiers = visuals:Column():AddSection("Notifiers")
local visualsSide = visuals:Column()
local worldVisuals, lightingVisuals = visualsSide:MultiSection({ names = { "World", "Lighting" } })
local visualLocal, visualLocalOptions, crosshair = visualsSide:Column():MultiSection({ names = { "Viewmodel", "Local", "Crosshair" } })
previewToggle(notifiers, "Item Notifier")
previewToggle(notifiers, "Exit Notifier")
previewToggle(worldVisuals, "Remove Grass")
previewToggle(worldVisuals, "Remove Foliage")
previewToggle(worldVisuals, "Remove Trees")
previewToggle(worldVisuals, "Grass Color")
previewToggle(lightingVisuals, "Override Ambient")
previewToggle(lightingVisuals, "Override Brightness")
previewToggle(visualLocal, "Viewmodel Enabled")
previewSlider(visualLocal, "Field of View", 60, 120, 90, "°")
previewToggle(visualLocalOptions, "Third Person")
previewToggle(crosshair, "Crosshair Enabled")
previewToggle(crosshair, "Spin")

if showCompanionPanels then
	local style = menu:CreatePanel("Style", {
		name = "StylePanel",
		image = "style",
		size = UDim2.fromOffset(394, 631),
		position = UDim2.new(0.5, 208, 0.5, -433),
	})
	local styleColumn = style:AddColumn()
	local theme = styleColumn:AddSection("Theme")
	local function colorRow(name, color, flag, alpha)
		local control = theme:Label({ name = name })
		control:Colorpicker({ name = name, color = color, alpha = alpha, flag = flag })
		return control
	end
	colorRow("Menu Accent", Color3.fromRGB(255, 98, 127), "accent")
	local contrast = theme:Label({ name = "Contrast" })
	contrast:Colorpicker({ name = "Low", color = Color3.fromRGB(16, 16, 16), flag = "low_contrast" })
	contrast:Colorpicker({ name = "High", color = Color3.fromRGB(13, 13, 13), flag = "high_contrast" })
	colorRow("Inline", Color3.fromRGB(34, 34, 34), "inline")
	colorRow("Outline", Color3.fromRGB(10, 10, 10), "outline")
	local textColor = theme:Label({ name = "Text Color" })
	textColor:Colorpicker({ name = "Text Color", color = Color3.fromRGB(224, 224, 224), flag = "text_color" })
	textColor:Colorpicker({ name = "Text Outline Color", color = Color3.fromRGB(0, 0, 0), flag = "text_outline" })
	colorRow("Glow", Color3.fromRGB(255, 98, 127), "glow", 0.2)
	theme:Dropdown({ name = "Tweening Style", items = { "Linear", "Sine", "Back", "Bounce", "Circular", "Cubic", "Elastic", "Exponential", "Quad", "Quart", "Quint" }, default = "Circular" })
	theme:Dropdown({ name = "Tweening Direction", items = { "In", "Out", "InOut" }, default = "InOut" })
	theme:Slider({ name = "Tweening Time", min = 0.05, max = 1, step = 0.01, default = 0.15, suffix = "s" })
	previewToggle(theme, "Pointer Design", true)

	local accessibility, otherStyle = styleColumn:MultiSection({ names = { "Accessibility", "Other" } })
	local uiBind = accessibility:Label({ name = "UI Bind" })
	uiBind:Keybind({ key = Enum.KeyCode.End })
	previewToggle(accessibility, "Keybind List")
	local watermark = previewToggle(accessibility, "Watermark", true)
	watermark:Configuration({ name = "Watermark Options" }, function(config)
		config:Dropdown({ name = "Watermark Elements", multi = true, items = { "Version", "FPS", "Ping", "UID", "Game", "Date", "Time" }, default = { "Version", "FPS", "Ping", "Game", "Date" } })
		config:Textbox({ name = "Custom Watermark", placeholder = "backtrack.tech", max = 20 })
	end)
	previewToggle(accessibility, "UI Management", true)
	previewToggle(accessibility, "Aero Snap", true)
	otherStyle:Slider({ name = "Animation Frequency", min = 15, max = 240, default = 240, suffix = "hz" })
	otherStyle:Slider({ name = "Animation Speed", min = 0.5, max = 3, step = 0.1, default = 1 })
	otherStyle:Slider({ name = "Blur Size", min = 0, max = 56, default = 20 })
	otherStyle:Slider({ name = "FPS Cap", min = 30, max = 1000, default = 240, suffix = "hz" })
	otherStyle:Button({ name = "Test Notification", callback = function() menu:Notify("Interface preview notification", 3) end })

	local configurationPanel = menu:CreatePanel("Configurations", {
		name = "ConfigurationsPanel",
		image = "configurations",
		size = UDim2.fromOffset(324, 438),
		position = UDim2.new(0.5, 208, 0.5, -433),
	})
	local configurations = configurationPanel:AddColumn():AddSection("Options")
	configurations:List({ name = "Configurations", height = 160, items = { "Default", "Example" } })
	configurations:Textbox({ placeholder = "Type here...", max = 30 })
	configurations:Button({ name = "Create", callback = function() print("Add your configuration callback here") end })
	configurations:Button({ name = "Delete", callback = function() print("Add your configuration callback here") end })
	configurations:Button({ name = "Load", callback = function() print("Add your configuration callback here") end })
	configurations:Button({ name = "Save", callback = function() print("Add your configuration callback here") end })
	configurations:Button({ name = "Refresh Configurations", callback = function() print("Add your configuration callback here") end })
	configurations:Button({ name = "Unload Configuration", callback = function() print("Add your configuration callback here") end })
	configurationPanel:SetVisible(false)

	local playerPanel = menu:CreatePanel("Playerlist", {
		name = "PlayerlistPanel",
		image = "playerlist",
		size = UDim2.fromOffset(529, 445),
		position = UDim2.new(0.5, -929, 0.5, -433),
	})
	local playerSection = playerPanel:AddColumn():AddSection("Playerlist")
	playerSection:List({ name = "Players", height = 340, items = { "Local player", "Example player", "Another player" } })

	local outputPanel = menu:CreatePanel("Output", {
		name = "OutputPanel",
		image = "output",
		size = UDim2.fromOffset(529, 267),
		position = UDim2.new(0.5, -929, 0.5, 14),
	})
	local outputSection = outputPanel:AddColumn():AddSection("Output")
	local output = outputSection:Output({ height = 160 })
	output:Add("Backtrack UI loaded", "INFO", Color3.fromRGB(154, 135, 254))
	output:Add("Interface preview ready", "SUCCESS", Color3.fromRGB(122, 255, 117))
	outputSection:Button({ name = "Clear Output", callback = function() output:Clear() end })
end

menu:CreateDock({ icon = "main" })
menu:CreateWatermark("backtrack.tech")
