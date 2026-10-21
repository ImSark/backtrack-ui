-- Requires an environment that supports game:HttpGet and loadstring.
-- This is a visual demo of the original menu layout. All callbacks are inert
-- examples; the library does not implement the source script's game behavior.
local libraryUrl = "https://raw.githubusercontent.com/ImSark/backtrack-ui/refs/heads/main/backtrack_ui.lua"
local libraryCacheBuster = tostring(math.floor(os.clock() * 1000000))
local BacktrackUI = loadstring(game:HttpGet(libraryUrl .. "?t=" .. libraryCacheBuster))()

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
	local deleteAsset = delfile or deletefile
	if type(deleteAsset) == "function" then
		for _, name in ipairs({ "fs-tahoma-8px.ttf", "Tahoma.font" }) do
			pcall(deleteAsset, folder .. "/" .. name)
		end
	end

	for _, name in ipairs({ "main", "style", "configurations", "playerlist", "output", "scroll", "pointer", "logo", "transparency", "glow4" }) do
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
	anchorPoint = Vector2.new(0.5, 0.5),
	position = UDim2.fromScale(0.5, 0.5),
	toggleKey = Enum.KeyCode.Delete,
	images = images,
})

local function previewToggle(section, name, default)
	local flag = name:lower():gsub("[^%w]+", "_")
	return section:Toggle({
		name = name,
		flag = flag ~= "" and flag or nil,
		default = default == true,
		callback = function(value)
			print(name .. ":", value)
		end,
	})
end

local function previewSlider(section, name, min, max, default, suffix, step)
	local flag = name:lower():gsub("[^%w]+", "_")
	return section:Slider({
		name = name,
		flag = flag ~= "" and flag or nil,
		min = min,
		max = max,
		default = default,
		step = step or 1,
		suffix = suffix or "",
	})
end

local function T(name, default, keybind, color, config, configControls, colorpickers)
	return {
		kind = "toggle",
		name = name,
		default = default,
		keybind = keybind,
		color = color,
		config = config,
		configControls = configControls,
		colorpickers = colorpickers,
	}
end

local function S(name, min, max, default, suffix, step)
	return { kind = "slider", name = name, min = min, max = max, default = default, suffix = suffix, step = step }
end

local function D(name, items, default, multi)
	return { kind = "dropdown", name = name, items = items, default = default, multi = multi }
end

local function B(name)
	return { kind = "button", name = name }
end

local function L(name, colorpickers)
	return { kind = "label", name = name, colorpickers = colorpickers }
end

local X = { kind = "splitter" }

local white = Color3.fromRGB(255, 255, 255)
local black = Color3.fromRGB(0, 0, 0)
local green = Color3.fromRGB(0, 255, 0)
local yellow = Color3.fromRGB(255, 255, 0)
local red = Color3.fromRGB(255, 0, 0)
local accent = Color3.fromRGB(255, 98, 127)
local fontChoices = { "Micro", "Minecraftia", "Monaco", "Nokia", "Smallest Pixel", "Tahoma", "Verdana" }

local function colors(names, color, alpha)
	local result = {}
	for _, name in ipairs(names) do
		table.insert(result, { name = name, color = color or white, alpha = alpha })
	end
	return result
end

local function populate(section, definitions)
	for _, item in ipairs(definitions) do
		local control
		if item.kind == "toggle" then
			control = previewToggle(section, item.name, item.default)
		elseif item.kind == "label" then
			control = section:Label({ name = item.name })
		end
		if control then
			if item.config then
				control:Configuration({ name = item.config }, function(configuration)
					populate(configuration, item.configControls or {})
				end)
			end
			if item.color then control:Colorpicker({ name = item.name, color = item.color }) end
			for _, picker in ipairs(item.colorpickers or {}) do
				control:Colorpicker(picker)
			end
			if item.keybind then
				control:Keybind({ name = item.name, mode = type(item.keybind) == "string" and item.keybind or nil })
			end
		elseif item.kind == "slider" then
			previewSlider(section, item.name, item.min, item.max, item.default, item.suffix, item.step)
		elseif item.kind == "dropdown" then
			local default = item.default
			if item.multi and default ~= nil and type(default) ~= "table" then default = { default } end
			section:Dropdown({
				name = item.name,
				flag = item.name:lower():gsub("[^%w]+", "_") ~= "" and item.name:lower():gsub("[^%w]+", "_") or nil,
				items = item.items,
				default = default,
				multi = item.multi,
			})
		elseif item.kind == "button" then
			section:Button({
				name = item.name,
				callback = function() print(item.name .. " clicked") end,
			})
		elseif item.kind == "textbox" then
			section:Textbox({ name = item.name, placeholder = item.placeholder, max = item.max })
		elseif item.kind == "splitter" then
			section:Splitter(item)
		end
	end
end

-- This reproduces the source's visible tab, column, section, and root-control
-- layout. Everything here is presentation-only; no game actions are attached.
local combat = menu:AddTab("Combat")
local combatLeft = combat:Column()
local combatAim, combatVisualization = combatLeft:MultiSection({ names = { "Aiming", "Visualization" } })
local combatRight = combat:Column()
local combatOther = combatRight:AddSection("Other")
local weaponMods = combatRight:Column():AddSection("Weapon Modifications")

populate(combatAim, {
	T("Silent Aim", false, true, nil, "Silent Aim Options", {
		T("Force Hit", false, true), X, T("Target Friendlies", false, true), T("Prioritize Enemies", true, true), X,
		D("Target Sorting Type", { "Closest To Mouse", "Distance" }, "Closest To Mouse"), X,
		T("Target Players", true, true), T("Target AI", true, true), T("Target MI24V Helicopter", true, true),
	}),
	T("Aim Assist", false, "Hold", nil, "Aim Assist Options", {
		D("Method", { "Camera", "Mouse" }, "Camera"), S("Smoothing", 1, 100, 20),
	}),
	X,
	T("Auto Shoot", false, true, nil, "Auto Shoot Options", {
		S("Delay", 0, 1, 0.01, "s", 0.01), S("Scan Rate", 0.01, 1, 0.2, "s", 0.01),
	}),
	X,
	T("Wall Check", false, true), T("Dead Check", false, true),
	T("Distance Check", false, true, nil, "Distance Check Options", { S("Maximum Distance", 1, 3000, 1300, "m") }), X,
	T("Use FOV", true, true), S("FOV Radius", 1, 1250, 150), S("Hitchance", 1, 100, 100, "%"),
	D("Hitboxes", { "Head", "Torso", "HumanoidRootPart" }, "Head", true),
})
populate(combatVisualization, {
	T("Target Indicator", false, false, nil, "Indicator Options", {
		D("Position", { "Above", "Below", "Left", "Right" }, "Above"), D("Font", fontChoices, "Tahoma"),
	}, colors({ "Low" }, accent)),
	T("Inventory Viewer", false, false, nil, "Inventory Viewer Options", {
		D("Position", { "Left", "Right" }, "Right"), S("Width", 100, 500, 250), S("Height", 100, 500, 300),
	}), X,
	T("Enable FOV", false, false, nil, "FOV Options", {
		T("Gradient"), S("Thickness", 1, 5, 1), S("Transparency", 0, 1, 0.5, nil, 0.01),
	}, colors({ "Gradient Color Left", "Gradient Color Right" }, accent)),
	T("Enable Snapline", false, false, nil, "Snapline Options", {
		D("Position", { "Top", "Center", "Bottom" }, "Bottom"), S("Thickness", 1, 5, 1),
	}, colors({ "Gradient Color Local", "Gradient Color Target" }, accent)), X,
	T("Override Headshot Hitsound", false, false, nil, "Hitsound Options", { D("Hitsound", { "Default", "Bell", "Rust" }, "Default"), S("Volume", 0, 2, 1, nil, 0.01) }),
	T("Override Body Hitsound", false, false, nil, "Hitsound Options", { D("Hitsound", { "Default", "Bell", "Rust" }, "Default"), S("Volume", 0, 2, 1, nil, 0.01) }),
	T("Override Killsound"), X,
	T("Override Shoot Sound", false, false, nil, "Shoot Sound Options", { D("Sound", { "Default", "Suppressed", "Rifle" }, "Default"), S("Volume", 0, 2, 1, nil, 0.01) }), X,
	T("Bullet Tracers", false, false, nil, "Bullet Tracer Options", { S("Lifetime", 0.1, 5, 1, "s", 0.1) }, colors({ "Gradient Color Start", "Gradient Color End" }, accent)),
	T("Hitmarkers", false, false, nil, "Hitmarker Options", { S("Size", 1, 20, 5) }, colors({ "Gradient Color Left", "Gradient Color Right" }, accent)),
	T("Bullet Impacts", false, false, nil, "Bullet Impact Options", { S("Lifetime", 0.1, 5, 1, "s", 0.1) }, colors({ "Impact Color" }, accent)),
	T("Hit VFX", false, false, nil, "Hit VFX Options", { D("Effect", { "Default", "Spark", "Ring" }, "Default") }),
})
populate(combatOther, {
	T("Server Desync Resolver", false, true), T("Stream Sync", false, true), X,
	T("Sit on Resolve", false, true), X,
	T("Underground Resolver", false, true, nil, "Underground Resolver Options", {
		S("Depth", 5, 50, 15, "m"), D("Method", { "Default", "Velocity" }, "Default"),
	}),
	T("Sky Peek", false, "Hold", nil, "Sky Peek Options", { S("Height", 1, 300, 50, "m"), S("Timeout", 0.1, 3, 1, "s", 0.1) }),
	T("TP Peek", false, "Hold", nil, "TP Peek Options", {
		S("Height", 1, 300, 50, "m"), S("Timeout", 0.1, 3, 1, "s", 0.1), D("Method", { "Classic", "CFrame" }, "Classic"),
	}),
})
populate(weaponMods, {
	T("Instant Aim"), T("Instant Bullet"), T("Instant Equip"), T("Instant Lean"), T("No Bobbing"),
	T("No Recoil"), T("No Sway"), T("Remove Muzzle Effects"), T("Remove Obstructions"),
	T("Remove Sprinting Animation"), T("Remove Spread"), T("Unlock Firemodes"), T("Double Tap", false, true),
	T("Rapid Fire", false, false, nil, "Rapid Fire Options", { S("Fire Rate", 1, 100, 1) }),
	T("Rapid Knife", false, false, nil, "Rapid Knife Options", { S("Swing Rate", 1, 100, 1) }),
})

local playersTab = menu:AddTab("Players")
local playerSections = playersTab:Column()
local playerESP, npcESP, otherESP = playerSections:MultiSection({ names = { "Players", "NPC", "Other" } })
local playerSide = playersTab:Column()
playerSide:AddSection("ESP Preview")
local playerOptions = playerSide:Column():AddSection("Options")

local function espTextOptions()
	return {
		D("Font", fontChoices, "Tahoma"),
		T("Render Outline", true, false, nil, nil, nil, colors({ "Outline Color" }, black)),
		L("Color", colors({ "Text Color" }, white)),
	}
end

local function populateCharacterESP(section)
	local boxOptions = {
		L("Color", colors({ "Gradient Top", "Gradient Bottom" }, white)),
		S("Gradient Rotation", 0, 180, 90, "°"),
		T("Render Outline", true, false, nil, nil, nil, colors({ "Outline Color" }, black)),
		T("Glow", false, false, nil, nil, nil, colors({ "Gradient Top", "Gradient Bottom" }, white, 0.5)),
		T("Fill", false, false, nil, nil, nil, colors({ "Gradient Top", "Gradient Bottom" }, white, 0.5)),
		S("Fill Gradient Rotation", 0, 180, 90, "°"),
	}
	local healthColors = colors({ "Color 1" }, green)
	for _, picker in ipairs(colors({ "Color 2" }, yellow)) do table.insert(healthColors, picker) end
	for _, picker in ipairs(colors({ "Color 3" }, red)) do table.insert(healthColors, picker) end
	local healthOptions = {
		L("Color", healthColors),
		T("Render Outline", true, false, nil, nil, nil, colors({ "Outline Color" }, black)),
		T("Glow", false, false, nil, nil, nil, colors({ "Color 1", "Color 2", "Color 3" }, white, 0.5)),
		T("Background", false, false, nil, nil, nil, colors({ "Color 1", "Color 2", "Color 3" }, white, 0.5)),
		T("Health Flag", false, false, nil, "Health Flag Options", {
			T("Damaged Only"),
			D("Position", { "Left", "Right", "Top", "Bottom" }, "Left"),
			D("Font", fontChoices, "Tahoma"),
			T("Render Outline", true, false, nil, nil, nil, colors({ "Outline Color" }, black)),
			T("Text Color", false, false, white),
			S("Gradient Layers", 1, 10, 3), S("Thickness", 1, 5, 1),
			T("Animate"), D("Easing Style", { "Linear", "Sine", "Back", "Bounce", "Circular", "Cubic", "Elastic", "Exponential", "Quad", "Quart", "Quint" }, "Linear"),
			D("Direction", { "In", "Out", "InOut" }, "InOut"),
		}),
	}
	local weaponOptions = {
		T("Icon", false, false, nil, nil, nil, colors({ "Image Color" }, white)),
		S("Size", 8, 32, 16), D("Sampling", { "Default", "Pixelated" }, "Default"),
		D("Font", fontChoices, "Tahoma"), T("Render Outline", true, false, nil, nil, nil, colors({ "Outline Color" }, black)),
		L("Color", colors({ "Text Color" }, white)),
	}
	local desyncOptions = { S("Threshold", 0, 100, 50, "%") }
	for _, item in ipairs(espTextOptions()) do table.insert(desyncOptions, item) end

	populate(section, {
		T("ESP Enabled", false, true, nil, "ESP Options", { S("Render Distance", 1, 3000, 1300, "m") }),
		X,
		T("Bounding Box", false, false, nil, "Bounding Box Options", boxOptions),
		T("Health Bar", false, false, nil, "Health Bar Options", healthOptions),
		X,
		T("Name", false, false, nil, "Name Options", textFeatureOptions),
		T("Distance", false, false, nil, "Distance Options", espTextOptions()),
		T("Weapon", false, false, nil, "Weapon Options", weaponOptions),
		X,
		T("KD", false, false, nil, "KD Options", espTextOptions()),
		T("Invisible", false, false, nil, "Invisible Options", espTextOptions()),
		T("Desyncing", false, false, nil, "Desyncing Options", desyncOptions),
		T("Visible", false, false, nil, "Visible Options", espTextOptions()),
		D("Flag Font", fontChoices, "Tahoma"),
		X,
		T("Chams", false, false, nil, nil, nil, colors({ "Cham Color" }, white)),
		T("Glow Chams", false, false, nil, "Glow Cham Options", {
			D("Type", { "Outer", "Inner", "Both" }, "Both"), S("Intensity", 0, 10, 1),
			T("Cham Color", false, false, white),
		}),
		T("Highlight Chams", false, false, nil, "Highlight Options", {
			D("Type", { "Always On Top", "Occluded" }, "Always On Top"),
			T("Fill Color", false, false, white), T("Outline Color", false, false, black),
		}),
	})
end

populateCharacterESP(playerESP)
populateCharacterESP(npcESP)

local function markerOptions(kind)
	local options = {
		T("Render Outline", true, false, nil, nil, nil, colors({ "Outline Color" }, black)),
		X,
		T("Icon", false, false, nil, nil, nil, colors({ "Image Color" }, white)),
		T("Distance"),
		X,
		D("Font", fontChoices, "Tahoma"),
	}
	if kind == "Corpses" then
		table.insert(options, 6, T("Local Corpse", false, false, nil, nil, nil, colors({ "Text Color", "Image Color" }, white)))
	elseif kind == "Dropped Items" then
		table.insert(options, 4, S("Icon Size", 8, 32, 16))
	end
	return options
end

populate(otherESP, {
	T("ESP Enabled", false, true, nil, "ESP Options", { S("Render Distance", 1, 1300, 1300, "m") }),
	X,
	T("Exits", false, false, white, "Exit Options", markerOptions("Exits")),
	T("Vehicles", false, false, white, "Vehicle Options", markerOptions("Vehicles")),
	T("Corpses", false, false, white, "Corpse Options", markerOptions("Corpses")),
	T("Dropped Items", false, false, white, "Dropped Item Options", markerOptions("Dropped Items")),
	T("MI24V Helicopter", false, false, white, "Heli Options", markerOptions("Helicopter")),
})
populate(playerOptions, {
	D("Bounding Type", { "Static", "Dynamic" }, "Static"),
	S("Dynamic Padding", 0.7, 2, 1, nil, 0.01), S("Static Width", 2, 4, 3.6, nil, 0.1), S("Static Height", 5, 5.5, 5, nil, 0.1),
	X, T("Display Measurement Unit", true), D("Measurement Unit", { "Studs", "Meters" }, "Meters"),
	X, D("Font Case", { "Uppercase", "Lowercase", "Titlecase" }, "Lowercase"), S("Update Rate", 30, 240, 240, "hz"),
	X, B("Test Healthbar Animation"),
})

local misc = menu:AddTab("Misc")
local movement, exploits = misc:Column():MultiSection({ names = { "Movement", "Exploits" } })
local miscSide = misc:Column()
local localOptions, chat = miscSide:MultiSection({ names = { "Local", "Chat" } })
local replication, replicationVisuals = miscSide:Column():MultiSection({ names = { "Replication", "Visualization" } })
populate(movement, {
	T("Flyhack", false, true, nil, "Flyhack Options", {
		S("Horizontal Speed", 0.1, 100, 20, nil, 0.1), S("Vertical Speed", 0.1, 100, 20, nil, 0.1), S("Speed Multiplier", 0.1, 10, 1, nil, 0.1),
	}),
	T("Long Jump", false, "Hold", nil, "Long Jump Options", {
		S("Forward Force", 1, 15, 8, nil, 0.1), S("Upward Force", 0, 10, 1.5, nil, 0.1), S("Cooldown", 0.1, 3, 1, nil, 0.1),
	}), X,
	T("Speedhack", false, true, nil, "Speedhack Options", { S("Speed", 0.1, 30, 20, nil, 0.1) }),
	T("Jumphack", false, true, nil, "Jumphack Options", { S("Height", 0.1, 20, 3, nil, 0.1) }),
	T("Gravity", false, true, nil, "Gravity Options", { S("Gravity", 1, 300, 196.2) }),
	T("Max Slope Angle", false, false, nil, "Gravity Options", { S("Slope Angle", 1, 89, 89) }), X,
	T("Bunnyhop", false, true), T("Remove Fall Damage", false, true),
})
populate(exploits, {
	B("Reset Character"), X, D("Detonation Mode", { "All", "One" }, "All"), B("Explode Landmines"),
	D("UAZ Spawn Type", { "Farthest", "Nearest", "Random" }, "Nearest"), B("Spawn UAZ"), X,
	D("Traders", { "Anna", "Blaze", "Boss", "Designer", "Jake", "Mihkel", "Nurse", "Seryozha" }, "Blaze"),
	B("Teleport Traders"), B("Unlock Traders"), X, B("Sort Inventory"), B("Sort Vault"),
})
populate(localOptions, {
	T("Jesus", false, true), T("No Drown", false, true), T("No Water Physics", false, true), X,
	T("Multi Use", false, true, nil, "Multi Use Options", { S("Times", 2, 4, 3, "x") }),
	T("Pickup Aura", false, true, nil, "Pickup Aura Options", { S("Scan Interval", 0.1, 1, 1, nil, 0.01), S("Range", 0.1, 20, 8, "st", 0.1) }),
})
populate(chat, { T("Trash Talk"), D("Trash Talk Type", { "Backtrack", "Casual", "Exploit", "Passive" }, "Backtrack") })
populate(replication, {
	T("Position Spoofer", false, true), S("X Offset", -10, 10, 0, nil, 0.1), S("Y Offset", -4, 6, 0, nil, 0.1), S("Z Offset", -10, 10, 0, nil, 0.1),
	X, T("Rotation Spoofer", false, true, nil, "Rotation Spoofer Options", {
		T("Spin Roll", false, true), S("Roll Speed", 0.1, 25, 1, nil, 0.1),
		T("Spin Pitch", false, true), S("Pitch Speed", 0.1, 25, 1, nil, 0.1),
		T("Spin Yaw", false, true), S("Yaw Speed", 0.1, 25, 1, nil, 0.1),
	}), S("Roll", -180, 180, 0), S("Pitch", -180, 180, 0), S("Yaw", -180, 180, 0),
	X, T("Play Animation", false, true, nil, "Animation Options", {
		{ kind = "textbox", name = "", placeholder = "Enter Animation ID", max = 30 },
		S("Time Position", 0, 15, 0, nil, 0.0001), S("Speed", 0, 10, 0, nil, 0.1),
	}), X, T("Custom Pitch", false, true), S("", -0.7, 0.7, 0, nil, 0.1),
})
populate(replicationVisuals, {
	T("Visualize Server Position", false, false, Color3.fromRGB(255, 98, 127), "Cham Options", {
		S("Glow Intensity", 1, 5, 1.5, nil, 0.01), D("Type", { "Default", "Flat", "Shaded" }, "Default"),
	}),
	T("Third Person Only"), T("Tween Position"), T("Animate", true),
})

local visuals = menu:AddTab("Visuals")
local notifiers = visuals:Column():AddSection("Notifiers")
local visualsSide = visuals:Column()
local worldVisuals, lightingVisuals = visualsSide:MultiSection({ names = { "World", "Lighting" } })
local visualLocal, visualLocalOptions, crosshair = visualsSide:Column():MultiSection({ names = { "Viewmodel", "Local", "Crosshair" } })
populate(notifiers, {
	T("Report Notifications", false, false, nil, "Report Notification Options", {
		T("Sound"), S("Volume", 1, 2, 1, nil, 0.1), T("Flashing"), S("Duration", 1, 10, 3, nil, 0.1),
	}),
	B("Show Current Reports"), X,
	T("Enable Join Notifications", false, false, nil, "Join Notification Options", {
		T("Display KD"), T("Display Hours Played"), S("Duration", 1, 10, 3, nil, 0.1),
	}),
	T("Enable Leave Notifications", false, false, nil, "Leave Notification Options", {
		T("Display KD"), T("Display Hours Played"), S("Duration", 1, 10, 3, nil, 0.1),
	}),
	T("Flashing Notifications"), X,
	T("Flare Calls"), T("Supply Drops"), T("Notification Sound"), S("Notification Volume", 0.1, 2, 1, nil, 0.1),
	T("Flashing Notifications"), S("Notification Duration", 0.5, 3, 3, nil, 0.1),
})
populate(worldVisuals, {
	T("Remove Grass"), T("Remove Foliage"), T("Remove Trees"), X,
	T("Grass Color", false, false, Color3.fromRGB(98, 151, 108)),
	T("Ground Color", false, false, Color3.fromRGB(128, 108, 84)),
	T("LeafyGrass Color", false, false, Color3.fromRGB(79, 134, 85)),
	T("Rock Color", false, false, Color3.fromRGB(110, 110, 110)),
	T("Sand Color", false, false, Color3.fromRGB(191, 174, 127)),
})
populate(lightingVisuals, {
	T("Override Ambient", false, false, nil, nil, nil, colors({ "Ambient Color", "Outdoor Ambient Color" }, white)), X,
	T("Override Brightness"), S("Brightness", 0, 75, 2), X,
	T("Override Clock Time"), S("Clock Time", 0, 24, 22.9, nil, 0.1), X,
	T("Override Fog", false, false, nil, "Fog Options", { S("Density", 0, 1, 0, nil, 0.01), S("Offset", 0, 1, 0, nil, 0.01) }),
	T("Override Fog Colors", false, false, nil, nil, nil, colors({ "Color", "Decay" }, white)), X,
	T("Override Glare", false, false, nil, "Glare Options", { S("Glare", 0, 10, 0, nil, 0.1) }),
	T("Override Haze", false, false, nil, "Haze Options", { S("Haze", 0, 10, 0, nil, 0.1) }),
	T("Override Bloom", false, false, nil, "Bloom Options", {
		S("Intensity", 0, 10, 0.5, nil, 0.1), S("Size", 0, 100, 56, nil, 0.1), S("Threshold", -1, 1, 0.8, nil, 0.1),
	}),
})
populate(visualLocal, {
	T("Override Viewmodel", false, false, nil, "Viewmodel Options", {
		T("Remove Clothing"), T("Apply Highlight", false, false, nil, nil, nil, colors({ "Instance Fill Color", "Instance Outline Color" }, Color3.fromRGB(255, 98, 127), 0.5)),
	}),
	T("Override Weapon", false, false, nil, "Weapon Options", { S("Field Of View", 1, 120, 90), S("Offset X", -10, 10, 0), S("Offset Y", -10, 10, 0) }),
	T("Override Arms", false, false, nil, "Arm Options", { S("Transparency", 0, 1, 0, nil, 0.01) }),
	T("Override Viewmodel Offset", false, false, nil, "Offset Options", { S("X Offset", -10, 10, 0), S("Y Offset", -10, 10, 0), S("Z Offset", -10, 10, 0) }),
})
populate(visualLocalOptions, {
	T("Third Person"), X,
	T("Self Chams", false, false, nil, "Self Cham Options", {
		D("Type", { "Default", "Flat", "Shaded" }, "Default"), S("Glow Intensity", 1, 5, 1.5, nil, 0.01),
	}), X, T("Aspect Ratio", false, false, nil, "Aspect Ratio Options", { S("Ratio", 0.5, 3, 1.78, nil, 0.01) }),
	T("Override FOV"), S("FOV Value", 1, 120, 90), X,
	T("Enable Removals"), D("Removals", { "Flashbang", "Gas Mask", "Parallax", "Visor", "Inventory Background", "Inventory Blur", "Inventory Decoration" }, { "Visor" }, true),
	T("Override Whiz Volume"), S("", 0, 2, 0.5, nil, 0.01), X,
	T("Look Indicator", false, false, Color3.fromRGB(255, 98, 127)), S("Threshold", 75, 100, 85, "%"),
	T("Session Data", false, false, nil, "Data Options", {
		D("Data Elements", { "Player Count", "Server Time", "Weather", "KD", "Kills", "Deaths" }, { "KD", "Kills", "Deaths" }, true),
	}),
	T("Spoof Client Data"), T("Hide UI", false, true),
	D("Hide Elements", { "Main Gui", "Server Info" }, { "Main Gui", "Server Info" }, true),
})
populate(crosshair, {
	T("Enable Crosshair", false, false, Color3.fromRGB(255, 98, 127)), T("Outline", true, false, Color3.fromRGB(0, 0, 0)),
	D("Position", { "Center", "Mouse", "Target" }, "Center"), S("Gap", 3, 100, 18), S("Length", 1, 75, 37),
	S("Width", 1, 4, 1), S("Rotation", -180, 180, 0), T("Spin"), S("Spin Speed", -5, 5, 1, nil, 0.1),
	T("Resize", false, false, nil, "Animation Options", {
		T("Animate Length"), S("Length Value", 1, 75, 19), X,
		T("Animate Gap"), S("Gap Value", 3, 100, 36), X,
		S("Speed", 0.01, 5, 1, nil, 0.01),
	}),
})

local consoleOutput
local function logConsole(message, level, color)
	if consoleOutput then consoleOutput:Add(message, level, color) end
	print("[BacktrackUI]", message)
end

local configTab = menu:AddTab("Config")
local profileList
local profileName
local profiles = { "Default", "Example" }
local profilesSection = configTab:Column():AddSection("Profiles")
local profileActions = configTab:Column():AddSection("Profile Actions")
profileName = profileActions:Textbox({ name = "Profile Name", default = "Default", placeholder = "Enter a profile name", max = 32 })
profileList = profilesSection:List({
	name = "Saved Profiles",
	height = 230,
	items = profiles,
	callback = function(value)
		profileName:Set(tostring(value), true)
		logConsole("Selected profile: " .. tostring(value), "CONFIG")
	end,
})
profileActions:ButtonHolder({ name = "Actions" })
profileActions:Button({ name = "Create Demo Profile", callback = function()
	local name = profileName:Get()
	if name == "" then return end
	table.insert(profiles, name)
	profileList:SetItems(profiles)
	logConsole("Created demo profile: " .. name, "CONFIG")
end })
profileActions:Button({ name = "Save Demo Profile", callback = function()
	logConsole("Save callback ready for profile: " .. profileName:Get(), "CONFIG")
end })
profileActions:Button({ name = "Load Demo Profile", callback = function()
	logConsole("Load callback ready for profile: " .. profileName:Get(), "CONFIG")
end })
profileActions:Button({ name = "Delete Demo Profile", callback = function()
	local name = profileName:Get()
	for index, profile in ipairs(profiles) do
		if profile == name then table.remove(profiles, index); break end
	end
	profileList:SetItems(profiles)
	logConsole("Removed demo profile: " .. name, "CONFIG")
end })

local themeTab = menu:AddTab("Theme")
local themePresets = themeTab:Column():AddSection("Presets")
local themeColors = themeTab:Column():AddSection("Colors")
local presets = {
	Rose = { accent = Color3.fromRGB(255, 98, 127), glow = Color3.fromRGB(255, 98, 127) },
	Violet = { accent = Color3.fromRGB(154, 135, 254), glow = Color3.fromRGB(154, 135, 254) },
	Ocean = { accent = Color3.fromRGB(83, 190, 222), glow = Color3.fromRGB(83, 190, 222) },
}
themePresets:Dropdown({
	name = "Color Preset",
	items = { "Rose", "Violet", "Ocean" },
	default = "Rose",
	callback = function(name)
		if presets[name] then
			menu:SetTheme(presets[name])
			logConsole("Applied " .. name .. " theme", "THEME")
		end
	end,
})
themePresets:Label({ name = "Changes apply immediately" })
themeColors:Colorpicker({ name = "Accent", color = menu.Theme.accent, callback = function(color)
	menu:SetTheme({ accent = color, glow = color })
	logConsole("Updated accent color", "THEME")
end })
themeColors:Colorpicker({ name = "Background", color = menu.Theme.background, callback = function(color)
	menu:SetTheme({ background = color, surface = color })
	logConsole("Updated background color", "THEME")
end })
themeColors:Colorpicker({ name = "Text", color = menu.Theme.text, callback = function(color)
	menu:SetTheme({ text = color })
	logConsole("Updated text color", "THEME")
end })

local consoleTab = menu:AddTab("Console")
local consoleSection = consoleTab:Column():AddSection("Output")
local consoleActions = consoleTab:Column():AddSection("Input")
consoleOutput = consoleSection:Output({ height = 270 })
consoleOutput:Add("Backtrack UI loaded", "INFO", Color3.fromRGB(154, 135, 254))
consoleOutput:Add("Console ready", "SUCCESS", Color3.fromRGB(122, 255, 117))
local consoleMessage = consoleActions:Textbox({ name = "Message", placeholder = "Type a message to log", max = 80 })
consoleActions:ButtonHolder({ name = "Console Actions" })
consoleActions:Button({ name = "Write Message", callback = function()
	local message = consoleMessage:Get()
	if message ~= "" then logConsole(message, "USER") end
end })
consoleActions:Button({ name = "Write Sample", callback = function()
	logConsole("This is a sample console entry", "INFO", Color3.fromRGB(154, 135, 254))
end })
consoleActions:Button({ name = "Clear Console", callback = function()
	consoleOutput:Clear()
end })

local dock = menu:CreateDock({ icon = "main", labels = true })
dock:AddButton("Config", "configurations", function()
	menu:SetVisible(true)
	configTab:SetActive(true)
end)
dock:AddButton("Theme", "style", function()
	menu:SetVisible(true)
	themeTab:SetActive(true)
end)
dock:AddButton("Console", "output", function()
	menu:SetVisible(true)
	consoleTab:SetActive(true)
end)
menu:CreateWatermark("backtrack.tech")
