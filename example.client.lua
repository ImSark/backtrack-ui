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
local customAsset = getcustomasset or getsynasset
if type(writefile) == "function" and type(customAsset) == "function" then
	local folder = "backtrack_ui_assets"
	if type(isfolder) == "function" and type(makefolder) == "function" then
		local ok, exists = pcall(isfolder, folder)
		if not ok or not exists then pcall(makefolder, folder) end
	end

	for _, name in ipairs({ "main", "style", "configurations", "playerlist", "output", "glow4" }) do
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
end

local menu = BacktrackUI.new({
	title = "backtrack.tech - " .. os.date("%b %d %Y"),
	name = "BacktrackUI",
	anchorPoint = showCompanionPanels and Vector2.zero or Vector2.new(0.5, 0.5),
	position = showCompanionPanels and UDim2.new(0.5, -398, 0.5, -433) or UDim2.fromScale(0.5, 0.5),
	toggleKey = Enum.KeyCode.End,
	images = images,
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

-- These are the four tabs and the compact two-column control layout used by
-- the source menu. The displayed controls only demonstrate the UI library.
local combat = menu:AddTab("Combat")
local combatAim = combat:Column():AddSection("Aiming")
local combatOther = combat:Column():AddSection("Other")
local weaponMods = combat:Column():AddSection("Weapon Modifications")

local silentAim = previewToggle(combatAim, "Silent Aim")
silentAim:Keybind({ name = "Silent Aim", flag = "silent_aim_bind", mode = "Hold" })
silentAim:Colorpicker({ name = "Aim Color", flag = "aim_color", color = Color3.fromRGB(255, 98, 127) })
local aimAssist = previewToggle(combatAim, "Aim Assist")
aimAssist:Keybind({ name = "Aim Assist", flag = "aim_assist_bind", mode = "Hold" })
previewToggle(combatAim, "Auto Shoot")
previewToggle(combatAim, "Wall Check")
previewToggle(combatAim, "Dead Check")
previewToggle(combatAim, "Distance Check")
previewSlider(combatAim, "Field of View", 1, 180, 90, "°")

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
previewToggle(weaponMods, "Instant Equip")
previewSlider(weaponMods, "Fire Rate", 1, 100, 10, "%")
previewSlider(weaponMods, "Reload Speed", 1, 100, 10, "%")

local playersTab = menu:AddTab("Players")
local playersColumn = playersTab:Column()
local playersSection = playersColumn:AddSection("Playerlist")
playersSection:List({
	name = "Players",
	height = 170,
	items = { "Local player", "Example player", "Another player" },
})
playersSection:Dropdown({ name = "Priority", flag = "player_priority", items = { "Enemy", "Neutral", "Friendly" }, default = "Neutral" })
playersSection:Button({ name = "Refresh Playerlist", callback = function() print("Playerlist preview refreshed") end })

local misc = menu:AddTab("Misc")
local movement = misc:Column():AddSection("Movement")
local localOptions = misc:Column():AddSection("Local")
local replication = misc:Column():AddSection("Replication")
previewToggle(movement, "Flyhack")
previewSlider(movement, "Horizontal Speed", 1, 100, 16)
previewSlider(movement, "Vertical Speed", 1, 100, 16)
previewToggle(movement, "Infinite Stamina")
previewToggle(localOptions, "Third Person")
previewToggle(localOptions, "Custom FOV")
previewSlider(localOptions, "Field of View", 60, 120, 90, "°")
previewToggle(replication, "Name Changer")
previewToggle(replication, "Fake Lag")

local visuals = menu:AddTab("Visuals")
local playerVisuals = visuals:Column():AddSection("Player ESP")
local worldVisuals = visuals:Column():AddSection("World")
local visualOther = visuals:Column():AddSection("Other")
previewToggle(playerVisuals, "ESP Enabled")
previewToggle(playerVisuals, "Bounding Box")
previewToggle(playerVisuals, "Name")
previewToggle(playerVisuals, "Distance")
previewToggle(playerVisuals, "Health Bar")
previewToggle(worldVisuals, "Remove Foliage")
previewToggle(worldVisuals, "Item ESP")
previewToggle(visualOther, "Snapline")
previewToggle(visualOther, "Field of View Circle")

if showCompanionPanels then
	local style = menu:CreatePanel("Style", {
		name = "StylePanel",
		image = "style",
		size = UDim2.fromOffset(394, 631),
		position = UDim2.new(0.5, 208, 0.5, -433),
	})
	style:AddLabel("Theme")
	style:AddLabel("Menu Accent                         #FF627F")
	style:AddLabel("Contrast              Low           High")
	style:AddLabel("Inline                                   #222222")
	style:AddLabel("Outline                                #0A0A0A")
	style:AddLabel("Text Color                            #E0E0E0")
	style:AddLabel("Text Outline                         #000000")
	style:AddLabel("Glow                                     #FF627F")
	style:AddLabel("Tweening Style                    Circular")
	style:AddLabel("Tweening Direction              InOut")
	style:AddLabel("Tweening Time                      0.15s")
	style:AddLabel("Pointer Design                     On")
	style:AddLabel("Accessibility")
	style:AddLabel("UI Bind                                End")
	style:AddLabel("Keybind List                         On")
	style:AddLabel("Watermark")
	style:AddLabel("UI Management                    On")
	style:AddLabel("Aero Snap                            On")
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
	configurationPanel:AddLabel("Options")
	configurationPanel:AddList({ "Default", "Example" })
	configurationPanel:AddLabel("Type here...")
	configurationPanel:AddButton("Create", function() print("Add your configuration callback here") end)
	configurationPanel:AddButton("Load", function() print("Add your configuration callback here") end)
	configurationPanel:SetVisible(false)

	local playerPanel = menu:CreatePanel("Playerlist", {
		name = "PlayerlistPanel",
		image = "playerlist",
		size = UDim2.fromOffset(529, 445),
		position = UDim2.new(0.5, -929, 0.5, -433),
	})
	playerPanel:AddLabel("Playerlist")
	playerPanel:AddList({ "Local player", "Example player", "Another player" })
	playerPanel:AddLabel("Priority")
	playerPanel:AddButton("Enemy     Neutral     Friendly", function() end)

	local outputPanel = menu:CreatePanel("Output", {
		name = "OutputPanel",
		image = "output",
		size = UDim2.fromOffset(529, 267),
		position = UDim2.new(0.5, -929, 0.5, 14),
	})
	outputPanel:AddLabel("Output")
	outputPanel:AddLabel("[INFO] Backtrack UI loaded")
	outputPanel:AddLabel("[READY] Interface preview")
	outputPanel:AddButton("Clear Output", function() end)
end

menu:CreateDock({ icon = "main" })
menu:CreateWatermark("backtrack.tech")
