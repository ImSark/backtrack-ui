--[[
    Liquid Glass UI
    A standalone Roblox/Luau interface library with translucent glass surfaces.
    It creates UI only; applications provide the behavior through callbacks.
]]

local LiquidGlassUI = {}
LiquidGlassUI.__index = LiquidGlassUI

LiquidGlassUI.Version = "1.2.0"
LiquidGlassUI.Theme = {
	background = Color3.fromRGB(242, 246, 251),
	glass = Color3.fromRGB(224, 233, 245),
	glassTop = Color3.fromRGB(255, 255, 255),
	glassBottom = Color3.fromRGB(201, 216, 235),
	control = Color3.fromRGB(255, 255, 255),
	controlHover = Color3.fromRGB(239, 247, 255),
	accent = Color3.fromRGB(0, 122, 255),
	accentSecondary = Color3.fromRGB(101, 185, 255),
	text = Color3.fromRGB(24, 32, 45),
	muted = Color3.fromRGB(78, 91, 110),
	border = Color3.fromRGB(255, 255, 255),
	glassTransparency = 0.34,
	controlTransparency = 0.58,
	positive = Color3.fromRGB(125, 225, 178),
	negative = Color3.fromRGB(255, 132, 153),
}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local getHiddenGui = gethui or get_hidden_gui

local function mergeTheme(overrides, base)
	local theme = {}
	for key, value in pairs(LiquidGlassUI.Theme) do theme[key] = value end
	for key, value in pairs(base or {}) do theme[key] = value end
	for key, value in pairs(overrides or {}) do theme[key] = value end
	return theme
end

local function create(className, properties, parent)
	local object = Instance.new(className)
	for key, value in pairs(properties or {}) do object[key] = value end
	object.Parent = parent
	return object
end

local function corner(parent, radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 12) }, parent)
end

local function outline(parent, color, transparency, thickness)
	return create("UIStroke", {
		Color = color or Color3.new(1, 1, 1),
		Transparency = transparency == nil and 0.78 or transparency,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function gradient(parent, top, bottom, rotation, transparency)
	return create("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = rotation or 90,
		Transparency = transparency or NumberSequence.new(0.25, 0.72),
	}, parent)
end

local function materialColors(theme)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, theme.glassTop),
		ColorSequenceKeypoint.new(0.5, theme.glass),
		ColorSequenceKeypoint.new(1, theme.glassBottom),
	})
end

local function invoke(callback, ...)
	if type(callback) ~= "function" then return end
	local ok, err = pcall(callback, ...)
	if not ok then warn("[LiquidGlassUI] callback error: " .. tostring(err)) end
end

local function asOptions(value)
	if type(value) == "table" then return value end
	return { name = value }
end

local function label(parent, text, options)
	options = options or {}
	return create("TextLabel", {
		Name = options.name or "Label",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = options.position or options.Position or UDim2.new(),
		Size = options.size or options.Size or UDim2.new(1, 0, 0, 20),
		Font = options.font or Enum.Font.Gotham,
		Text = tostring(text or ""),
		TextColor3 = options.color or Color3.new(1, 1, 1),
		TextSize = options.textSize or 13,
		TextXAlignment = options.align or Enum.TextXAlignment.Left,
		TextYAlignment = options.valign or Enum.TextYAlignment.Center,
		TextWrapped = options.wrapped == true,
		ZIndex = options.zIndex or 2,
	}, parent)
end

local function themeBinding(window, callback)
	table.insert(window._themeUpdaters, callback)
	local ok, err = pcall(callback)
	if not ok then warn("[LiquidGlassUI] theme update error: " .. tostring(err)) end
end

local function connect(window, signal, callback)
	local connection = signal:Connect(callback)
	table.insert(window._connections, connection)
	return connection
end

local function refract(window, gui, layer, control)
	if window.Options.refraction == false or (control and window.Options.refractionControls == false) then return end
	window._refractionTargetSerial = (window._refractionTargetSerial or 0) + 1
	local target = { Gui = gui, Options = { layer = layer or 0 }, Order = window._refractionTargetSerial }
	window._refractionTargets[gui] = target
	target.Connection = gui.Destroying:Connect(function() window._refractionTargets[gui] = nil end)
	if window._renderer then window._renderer:Attach(gui, target.Options) end
end

local function guiPointer(window)
	-- The ScreenGui uses IgnoreGuiInset=true, so mouse coordinates already
	-- share the same origin as the GUI objects.
	return UserInputService:GetMouseLocation()
end

local function normalizeKey(value)
	if typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode then return value end
	if type(value) == "string" then
		local ok, key = pcall(function() return Enum.KeyCode[value] end)
		if ok then return key end
	end
	return Enum.KeyCode.Unknown
end

local Tab = {}
Tab.__index = Tab
local Section = {}
Section.__index = Section

function LiquidGlassUI.new(options)
	options = options or {}
	local player = Players.LocalPlayer
	local parent = options.parent
	if not parent and type(getHiddenGui) == "function" then
		local ok, hiddenGui = pcall(getHiddenGui)
		if ok then parent = hiddenGui end
	end
	if not parent then
		assert(player, "LiquidGlassUI.new requires options.parent outside a LocalPlayer context")
		parent = player:WaitForChild("PlayerGui")
	end
	local guiName = options.name or "LiquidGlassUI"
	if options.replaceExisting then
		for _, existing in ipairs(parent:GetChildren()) do
			if existing:IsA("ScreenGui") and existing.Name == guiName then existing:Destroy() end
		end
		local camera = Workspace.CurrentCamera
		if camera then
			for _, effect in ipairs(camera:GetChildren()) do
				if effect:IsA("BlurEffect") and effect.Name == guiName .. "_BackdropBlur" then effect:Destroy() end
			end
		end
		for _, existing in ipairs(Workspace:GetChildren()) do
			if existing:IsA("Folder") and existing.Name == guiName .. "_Refraction" then existing:Destroy() end
		end
	end

	local window = setmetatable({
		Theme = mergeTheme(options.theme),
		Options = options,
		Tabs = {},
		_controls = {},
		_connections = {},
		_themeUpdaters = {},
		_destroyed = false,
		_visible = true,
		_minimized = false,
		_popup = nil,
		_listeningKeybind = nil,
		_refractionTargets = {},
		RefractionStatus = options.refraction == false and "disabled" or "loading",
	}, LiquidGlassUI)

	local screen = create("ScreenGui", {
		Name = guiName,
		ResetOnSpawn = options.resetOnSpawn == true,
		IgnoreGuiInset = true,
		DisplayOrder = options.displayOrder or 150,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, parent)
	window.Gui = screen
	connect(window, screen.Destroying, function() window:Destroy(true) end)
	local requestedBlur = options.blur
	local defaultBlur = options.refraction == false and 8 or 0
	window._blurSize = requestedBlur == false and 0 or math.clamp(tonumber(requestedBlur) or defaultBlur, 0, 56)
	if window._blurSize > 0 then
		local blur = Instance.new("BlurEffect")
		blur.Name = guiName .. "_BackdropBlur"
		blur.Size = 0
		blur.Enabled = true
		blur.Parent = Workspace.CurrentCamera
		window._blurEffect = blur
		connect(window, Workspace:GetPropertyChangedSignal("CurrentCamera"), function()
			blur.Parent = Workspace.CurrentCamera
		end)
		window._blurTween = TweenService:Create(blur, TweenInfo.new(0.36, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = window._blurSize })
		window._blurTween:Play()
	end

	local width = options.width or 740
	local height = options.height or 560
	local shell = create("Frame", {
		Name = "GlassWindow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = options.position or UDim2.fromScale(0.5, 0.5),
		Size = options.size or UDim2.fromOffset(width, height),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = window.Theme.glassTransparency,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 1,
	}, screen)
	window.Frame = shell
	corner(shell, 32)
	window.Outline = outline(shell, window.Theme.border, 0.12, 1.3)
	window.RimGradient = gradient(window.Outline, Color3.new(1, 1, 1), Color3.new(1, 1, 1), 35, NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.35, 0.76),
		NumberSequenceKeypoint.new(0.65, 0.9), NumberSequenceKeypoint.new(1, 0.12),
	}))
	window.GlassGradient = gradient(shell, window.Theme.glassTop, window.Theme.glassBottom, 100, NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.04), NumberSequenceKeypoint.new(0.18, 0.23),
		NumberSequenceKeypoint.new(0.65, 0.3), NumberSequenceKeypoint.new(1, 0.08),
	}))
	window.GlassGradient.Color = materialColors(window.Theme)
	local shadow = create("Frame", {
		Name = "GlassShadow",
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 0,
	}, shell)
	corner(shadow, 32)
	outline(shadow, Color3.fromRGB(8, 17, 30), 0.93, 12)
	window.Shadow = shadow
	local innerRim = create("Frame", {
		Name = "InnerLensEdge", Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4), BackgroundTransparency = 1,
		BorderSizePixel = 0, ZIndex = 2,
	}, shell)
	corner(innerRim, 30)
	local innerStroke = outline(innerRim, Color3.new(1, 1, 1), 0.58, 1.2)
	window.InnerRimGradient = gradient(innerStroke, Color3.new(1, 1, 1), Color3.new(1, 1, 1), 215, NumberSequence.new(0.1, 0.88))

	local sheen = create("Frame", {
		Name = "TopSheen",
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, shell)
	corner(sheen, 30)
	window.ReflectionGradient = gradient(sheen, Color3.new(1, 1, 1), Color3.new(1, 1, 1), 105, NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.72), NumberSequenceKeypoint.new(0.22, 0.97),
		NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(0.8, 0.98),
		NumberSequenceKeypoint.new(1, 0.83),
	}))
	window.Sheen = sheen

	local header = create("Frame", {
		Name = "Header",
		Position = UDim2.fromOffset(22, 18),
		Size = UDim2.new(1, -44, 0, 46),
		BackgroundTransparency = 1,
		Active = true,
		ClipsDescendants = true,
		ZIndex = 4,
	}, shell)
	window.Header = header
	local brand = create("Frame", {
		Name = "BrandMark",
		Position = UDim2.fromOffset(0, 5),
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = window.Theme.accent,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, header)
	window.BrandMark = brand
	corner(brand, 12)
window.BrandGradient = gradient(brand, window.Theme.accent, window.Theme.accentSecondary, 35, NumberSequence.new(0.05, 0.18))
label(brand, options.brandMark or "L", { size = UDim2.fromScale(1, 1), font = Enum.Font.GothamBold, textSize = 16, align = Enum.TextXAlignment.Center, zIndex = 6 })
	window.TitleLabel = label(header, options.title or "Liquid Glass", {
		position = UDim2.fromOffset(45, 1),
		size = UDim2.new(1, -130, 0, 23),
		font = Enum.Font.GothamSemibold,
		textSize = 19,
		zIndex = 5,
	})
	window.SubtitleLabel = label(header, options.subtitle or "A translucent workspace", {
		position = UDim2.fromOffset(45, 23),
		size = UDim2.new(1, -130, 0, 17),
		color = window.Theme.muted,
		textSize = 12,
		zIndex = 5,
	})
	window.CloseButton = create("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 5),
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = window.Theme.control,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "×",
		Font = Enum.Font.Gotham,
		TextSize = 22,
		TextColor3 = window.Theme.text,
		ZIndex = 6,
	}, header)
	corner(window.CloseButton, 17)
	window.CloseOutline = outline(window.CloseButton, window.Theme.border, 0.58, 1)
	window.CloseGradient = gradient(window.CloseButton, window.Theme.glassTop, window.Theme.glassBottom, 95, NumberSequence.new(0.48, 0.9))
	window.MinimizeButton = create("TextButton", {
		Name = "Minimize",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -40, 0, 5),
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = window.Theme.control,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "−",
		Font = Enum.Font.Gotham,
		TextSize = 22,
		TextColor3 = window.Theme.text,
		ZIndex = 6,
	}, header)
	corner(window.MinimizeButton, 17)
	window.MinimizeOutline = outline(window.MinimizeButton, window.Theme.border, 0.58, 1)
	window.MinimizeGradient = gradient(window.MinimizeButton, window.Theme.glassTop, window.Theme.glassBottom, 95, NumberSequence.new(0.48, 0.9))

	local separator = create("Frame", {
		Name = "HeaderSeparator",
		Position = UDim2.fromOffset(22, 92),
		Size = UDim2.new(1, -44, 0, 1),
		BackgroundColor3 = window.Theme.border,
		BackgroundTransparency = 0.86,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, shell)
	window.HeaderSeparator = separator

	local body = create("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(16, 104),
		Size = UDim2.new(1, -32, 1, -194),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, shell)
	window.Body = body
	local nav = create("ScrollingFrame", {
		Name = "Navigation",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(88, 56),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.46,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		ScrollBarImageColor3 = window.Theme.accent,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.X,
		ZIndex = 3,
	}, shell)
	corner(nav, 28)
	window.NavOutline = outline(nav, window.Theme.border, 0.2, 1.2)
	window.NavGradient = gradient(nav, window.Theme.glassTop, window.Theme.glassBottom, 100, NumberSequence.new(0.1, 0.4))
	window.Navigation = nav
	create("UIPadding", {
		PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
	}, nav)
	window.NavLayout = create("UIListLayout", {
		Padding = UDim.new(0, 6),
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, nav)
	local function layoutNavigation()
		local canvasWidth = window.NavLayout.AbsoluteContentSize.X + 16
		local maximum = math.max(88, shell.AbsoluteSize.X - 40)
		nav.Size = UDim2.fromOffset(math.min(maximum, math.max(88, canvasWidth)), 56)
		nav.CanvasSize = UDim2.fromOffset(canvasWidth, 0)
	end
	connect(window, window.NavLayout:GetPropertyChangedSignal("AbsoluteContentSize"), layoutNavigation)
	connect(window, shell:GetPropertyChangedSignal("AbsoluteSize"), layoutNavigation)
	local content = create("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, body)
	window.Content = content

	local footer = label(shell, options.footer or "LIQUID GLASS  ·  READY", {
		position = UDim2.fromOffset(23, 74),
		size = UDim2.new(1, -46, 0, 14),
		color = window.Theme.muted,
		textSize = 9,
		zIndex = 4,
	})
	window.Footer = footer

	themeBinding(window, function()
		if not shell.Parent then return end
		shell.BackgroundColor3 = Color3.new(1, 1, 1)
		shell.BackgroundTransparency = window.Theme.glassTransparency
		window.Outline.Color = window.Theme.border
		window.GlassGradient.Color = materialColors(window.Theme)
		window.BrandMark.BackgroundColor3 = window.Theme.accent
		window.BrandGradient.Color = ColorSequence.new(window.Theme.accent, window.Theme.accentSecondary)
		window.TitleLabel.TextColor3 = window.Theme.text
		window.SubtitleLabel.TextColor3 = window.Theme.muted
		window.CloseButton.TextColor3 = window.Theme.text
		window.MinimizeButton.TextColor3 = window.Theme.text
		window.CloseButton.BackgroundColor3 = window.Theme.control
		window.MinimizeButton.BackgroundColor3 = window.Theme.control
		window.CloseOutline.Color = window.Theme.border
		window.MinimizeOutline.Color = window.Theme.border
		window.CloseGradient.Color = ColorSequence.new(window.Theme.glassTop, window.Theme.glassBottom)
		window.MinimizeGradient.Color = ColorSequence.new(window.Theme.glassTop, window.Theme.glassBottom)
		window.HeaderSeparator.BackgroundColor3 = window.Theme.border
		window.Navigation.BackgroundColor3 = Color3.new(1, 1, 1)
		window.NavOutline.Color = window.Theme.border
		window.NavGradient.Color = materialColors(window.Theme)
		window.Navigation.ScrollBarImageColor3 = window.Theme.accent
		window.Footer.TextColor3 = window.Theme.muted
	end)

	local dragStart, dragOrigin
	connect(window, header.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragStart, dragOrigin = input.Position, shell.Position
		end
	end)
	connect(window, UserInputService.InputChanged, function(input)
		if window._visible and input.UserInputType == Enum.UserInputType.MouseMovement then
			local point = UserInputService:GetMouseLocation() - shell.AbsolutePosition
			local size = shell.AbsoluteSize
			if size.X > 0 and size.Y > 0 and point.X >= 0 and point.Y >= 0 and point.X <= size.X and point.Y <= size.Y then
				local x, y = point.X / size.X - 0.5, point.Y / size.Y - 0.5
				window.RimGradient.Rotation = 35 + x * 40 + y * 24
				window.InnerRimGradient.Rotation = 215 + x * 40 + y * 24
				window.ReflectionGradient.Offset = Vector2.new(x * 0.12, y * 0.06)
			end
		end
		if dragStart and dragOrigin and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			shell.Position = UDim2.new(dragOrigin.X.Scale, dragOrigin.X.Offset + delta.X, dragOrigin.Y.Scale, dragOrigin.Y.Offset + delta.Y)
		end
	end)
	connect(window, UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragStart, dragOrigin = nil, nil
		end
	end)
	connect(window, window.CloseButton.Activated, function() window:SetVisible(false) end)
	connect(window, window.MinimizeButton.Activated, function() window:SetMinimized(not window._minimized) end)
	connect(window, UserInputService.InputBegan, function(input, processed)
		if window._listeningKeybind and input.UserInputType == Enum.UserInputType.Keyboard then
			local keybind = window._listeningKeybind
			window._listeningKeybind = nil
			keybind:Set(input.KeyCode)
			return
		end
		if not processed and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == window.ToggleKey then
			window:Toggle()
		end
	end)
	window.ToggleKey = normalizeKey(options.toggleKey or Enum.KeyCode.RightShift)
	window._bodySize = body.Size
	window._savedSize = shell.Size
	refract(window, shell, 0)
	refract(window, nav, 1)
	if options.refraction ~= false then
		local fallbackTransparency = window.Theme.glassTransparency
		local customTransparency = options.theme and options.theme.glassTransparency ~= nil
		task.spawn(function()
			local renderer
			local clearApplied = false
			local function failed(message)
				if window._destroyed then return end
				window.RefractionStatus = "unavailable"
				window.RefractionError = tostring(message)
				if renderer then renderer:Destroy() end
				window._renderer = nil
				if clearApplied then window:SetTheme({ glassTransparency = fallbackTransparency }) end
				warn("[LiquidGlassUI] Refraction unavailable: " .. tostring(message))
				invoke(options.onRefractionError, tostring(message), window)
			end
			local ok, err = pcall(function()
				local factory = options.refractionRenderer
				if not factory then
					local base = options.refractionBaseUrl or "https://raw.githubusercontent.com/ImSark/backtrack-ui/main/"
					if base:sub(-1) ~= "/" then base = base .. "/" end
					local source = game:HttpGet(base .. "liquid_glass_renderer.lua?t=" .. tostring(math.floor(os.clock() * 1000000)))
					local chunk, compileError = loadstring(source, "LiquidGlassRenderer")
					assert(chunk, compileError)
					factory = chunk()
				end
				if window._destroyed then return end
				local rendererOptions = {}
				for key, value in pairs(options.refractionOptions or {}) do rendererOptions[key] = value end
				if options.refractionBaseUrl and not rendererOptions.assetBaseUrl then
					local base = options.refractionBaseUrl
					if base:sub(-1) ~= "/" then base = base .. "/" end
					rendererOptions.assetBaseUrl = base .. "assets/liquid-glass/"
				end
				rendererOptions.name = guiName
				rendererOptions.onError = failed
				if window._refractionStrength then rendererOptions.strength = window._refractionStrength end
				renderer = factory.new(rendererOptions)
				if window._destroyed then renderer:Destroy(); return end
				window._renderer = renderer
				local targets = {}
				for _, target in pairs(window._refractionTargets) do table.insert(targets, target) end
				table.sort(targets, function(a, b)
					if a.Options.layer == b.Options.layer then return a.Order < b.Order end
					return a.Options.layer < b.Options.layer
				end)
				for _, target in ipairs(targets) do renderer:Attach(target.Gui, target.Options) end
				renderer:SetEnabled(window._visible)
				window.RefractionStatus = "ready"
				window.RefractionError = nil
				if not customTransparency and window.Theme.glassTransparency == fallbackTransparency then
					clearApplied = true
					window:SetTheme({ glassTransparency = 0.84 })
				end
				invoke(options.onRefractionReady, renderer, window)
			end)
			if not ok then failed(err) end
		end)
	end

	return window
end

function LiquidGlassUI:GetRefractionStatus()
	return self.RefractionStatus, self.RefractionError
end

function LiquidGlassUI:SetRefractionStrength(value)
	self._refractionStrength = math.clamp(tonumber(value) or 3, 1.01, 8)
	if self._renderer then self._renderer:SetStrength(self._refractionStrength) end
	return self._refractionStrength
end

function LiquidGlassUI:SetTitle(title, subtitle)
	self.TitleLabel.Text = tostring(title or "")
	if subtitle ~= nil then self.SubtitleLabel.Text = tostring(subtitle) end
	return self
end

function LiquidGlassUI:SetTheme(overrides)
	if self._destroyed then return self.Theme end
	self.Theme = mergeTheme(overrides, self.Theme)
	for _, updater in ipairs(self._themeUpdaters) do
		local ok, err = pcall(updater)
		if not ok then warn("[LiquidGlassUI] theme update error: " .. tostring(err)) end
	end
	return self.Theme
end

function LiquidGlassUI:SetVisible(visible)
	self._visible = visible ~= false
	self.Gui.Enabled = self._visible
	if self._renderer then self._renderer:SetEnabled(self._visible) end
	if self._blurEffect then
		if self._blurTween then self._blurTween:Cancel() end
		self._blurEffect.Enabled = true
		self._blurTween = TweenService:Create(self._blurEffect, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = self._visible and self._blurSize or 0,
		})
		self._blurTween:Play()
	end
	return self._visible
end

function LiquidGlassUI:SetBlur(amount)
	self._blurSize = math.clamp(tonumber(amount) or 0, 0, 56)
	if self._blurSize > 0 and not self._blurEffect then
		local blur = Instance.new("BlurEffect")
		blur.Name = self.Gui.Name .. "_BackdropBlur"
		blur.Size = 0
		blur.Parent = Workspace.CurrentCamera
		self._blurEffect = blur
		connect(self, Workspace:GetPropertyChangedSignal("CurrentCamera"), function()
			blur.Parent = Workspace.CurrentCamera
		end)
	end
	if self._blurEffect then
		if self._blurTween then self._blurTween:Cancel() end
		self._blurEffect.Enabled = self._blurSize > 0
		self._blurTween = TweenService:Create(self._blurEffect, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = self._visible and self._blurSize or 0,
		})
		self._blurTween:Play()
	end
	return self._blurSize
end

function LiquidGlassUI:Toggle()
	return self:SetVisible(not self._visible)
end

function LiquidGlassUI:SetMinimized(minimized)
	self._minimized = minimized == true
	self.Body.Visible = not self._minimized
	self.Navigation.Visible = not self._minimized
	self.HeaderSeparator.Visible = not self._minimized
	self.Footer.Visible = not self._minimized
	self.Frame.Size = self._minimized and UDim2.new(self._savedSize.X.Scale, self._savedSize.X.Offset, 0, 82) or self._savedSize
	return self._minimized
end

function LiquidGlassUI:AddTab(name, iconText)
	local config = asOptions(name)
	if type(name) ~= "table" then config.iconText = iconText end
	local tab = setmetatable({
		_window = self,
		Name = tostring(config.name or config.title or ("Tab " .. tostring(#self.Tabs + 1))),
		IconText = config.iconText,
		Options = config,
		Sections = {},
	}, Tab)
	local order = #self.Tabs + 1
	local button = create("TextButton", {
		Name = "Nav_" .. tab.Name,
		Size = UDim2.fromOffset(config.width or 134, 40),
		BackgroundColor3 = self.Theme.control,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = order,
		ZIndex = 4,
	}, self.Navigation)
	corner(button, 20)
	local tabOutline = outline(button, self.Theme.border, 1, 1)
	local tabGradient = gradient(button, self.Theme.glassTop, self.Theme.glassBottom, 90, NumberSequence.new(0.18, 0.65))
	local icon = label(button, tab.IconText or string.upper(string.sub(tab.Name, 1, 1)), {
		position = UDim2.fromOffset(9, 0),
		size = UDim2.fromOffset(22, 40),
		font = Enum.Font.GothamSemibold,
		textSize = 12,
		align = Enum.TextXAlignment.Center,
		zIndex = 5,
	})
	local nameLabel = label(button, tab.Name, {
		position = UDim2.fromOffset(39, 0),
		size = UDim2.new(1, -48, 1, 0),
		font = Enum.Font.GothamMedium,
		textSize = 13,
		zIndex = 5,
	})
	local page = create("ScrollingFrame", {
		Name = "Page_" .. tab.Name,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = self.Theme.background,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = self.Theme.accent,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
		ZIndex = 3,
	}, self.Content)
	corner(page, 14)
	local pageOutline = outline(page, self.Theme.border, 1, 1)
	create("UIPadding", {
		PaddingTop = UDim.new(0, 13), PaddingBottom = UDim.new(0, 13),
		PaddingLeft = UDim.new(0, 13), PaddingRight = UDim.new(0, 13),
	}, page)
	local layout = create("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, page)
	local function refreshTheme()
		local selected = self.ActiveTab == tab
		button.BackgroundColor3 = self.Theme.control
		button.BackgroundTransparency = selected and 0.24 or 1
		tabOutline.Color = self.Theme.border
		tabOutline.Transparency = selected and 0.2 or 1
		tabGradient.Color = materialColors(self.Theme)
		icon.TextColor3 = selected and self.Theme.accent or self.Theme.muted
		nameLabel.TextColor3 = selected and self.Theme.text or self.Theme.muted
		page.BackgroundColor3 = self.Theme.background
		page.ScrollBarImageColor3 = self.Theme.accent
		pageOutline.Color = self.Theme.border
	end
	tab.Button = button
	tab.IconLabel = icon
	tab.NameLabel = nameLabel
	tab.Page = page
	tab.Layout = layout
	tab._refreshTheme = refreshTheme
	themeBinding(self, refreshTheme)
	connect(self, button.Activated, function() tab:Select() end)
	local canvasConnection = layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 26)
	end)
	table.insert(self._connections, canvasConnection)
	connect(self, page.ChildAdded, function() refreshTheme() end)
	table.insert(self.Tabs, tab)
	if not self.ActiveTab then tab:Select() end
	return tab
end

function Tab:Select()
	if self._window.ActiveTab then self._window.ActiveTab.Page.Visible = false end
	self._window.ActiveTab = self
	self.Page.Visible = true
	for _, tab in ipairs(self._window.Tabs) do tab:RefreshTheme() end
	return self
end

function Tab:RefreshTheme()
	if self._refreshTheme then self._refreshTheme() end
end

function Tab:AddSection(name, options)
	options = options or {}
	if type(name) == "table" then options, name = name, name.name end
	local section = setmetatable({ _tab = self, _window = self._window, Name = tostring(name or "Section"), _controls = {} }, Section)
	local card = create("Frame", {
		Name = "Section_" .. section.Name,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.74,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, self.Page)
	corner(card, 22)
	section.Outline = outline(card, self._window.Theme.border, 0.74, 1)
	section.GlassGradient = gradient(card, self._window.Theme.glassTop, self._window.Theme.glassBottom, 100, NumberSequence.new(0.28, 0.64))
	create("UIPadding", {
		PaddingTop = UDim.new(0, 11), PaddingBottom = UDim.new(0, 11),
		PaddingLeft = UDim.new(0, 13), PaddingRight = UDim.new(0, 13),
	}, card)
	local title = label(card, section.Name, {
		Size = UDim2.new(1, 0, 0, 23),
		font = Enum.Font.GothamSemibold,
		textSize = 12,
		zIndex = 5,
	})
	local content = create("Frame", {
		Name = "Controls",
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 4,
	}, card)
	create("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, content)
	section.Frame, section.Title, section.Content = card, title, content
	function section:RefreshTheme()
		if not self.Frame.Parent then return end
		self.Frame.BackgroundColor3 = Color3.new(1, 1, 1)
		self.Outline.Color = self._window.Theme.border
		self.GlassGradient.Color = materialColors(self._window.Theme)
		self.Title.TextColor3 = self._window.Theme.text
		for _, control in ipairs(self._controls) do
			if type(control.RefreshTheme) == "function" then control:RefreshTheme() end
		end
	end
	table.insert(self.Sections, section)
	themeBinding(self._window, function() section:RefreshTheme() end)
	return section
end

local function makeRow(section, height, name)
	return create("Frame", {
		Name = name or "ControlRow",
		Size = UDim2.new(1, 0, 0, height or 34),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, section.Content)
end

local function makeHandle(section, name, row)
	local handle = { Name = name, Row = row, _section = section, _window = section._window }
	function handle:SetVisible(visible) if self.Row then self.Row.Visible = visible ~= false end end
	function handle:Destroy() if self.Row and self.Row.Parent then self.Row:Destroy() end end
	table.insert(section._controls, handle)
	table.insert(section._window._controls, handle)
	return handle
end

function Section:Label(value)
	local options = asOptions(value)
	local text = options.name or options.text or "Label"
	local row = makeRow(self, options.height or 22, "LabelRow")
	local textLabel = label(row, text, { size = UDim2.fromScale(1, 1), textSize = options.textSize or 13, color = self._window.Theme.muted, zIndex = 6 })
	local handle = makeHandle(self, text, row)
	handle.Label = textLabel
	function handle:Set(textValue) self.Label.Text = tostring(textValue or "") end
	function handle:Get() return self.Label.Text end
	function handle:RefreshTheme() if self.Label.Parent then self.Label.TextColor3 = self._window.Theme.muted end end
	return handle
end

function Section:Divider()
	local row = makeRow(self, 10, "Divider")
	local line = create("Frame", {
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = self._window.Theme.border,
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, row)
	local handle = makeHandle(self, "Divider", row)
	function handle:RefreshTheme() if line.Parent then line.BackgroundColor3 = self._window.Theme.border end end
	return handle
end

function Section:Button(value)
	local options = asOptions(value)
	local name = options.name or options.text or "Button"
	local row = makeRow(self, options.height or 42, "ButtonRow")
	local button = create("TextButton", {
		Name = "Button",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = self._window.Theme.control,
		BackgroundTransparency = self._window.Theme.controlTransparency,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = tostring(name),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = self._window.Theme.text,
		ZIndex = 6,
	}, row)
	corner(button, 21)
	local buttonOutline = outline(button, self._window.Theme.border, 0.58, 1)
	local buttonGradient = gradient(button, self._window.Theme.glassTop, self._window.Theme.glassBottom, 95, NumberSequence.new(0.45, 0.88))
	refract(self._window, button, 2, true)
	local handle = makeHandle(self, name, row)
	handle.Button = button
	function handle:RefreshTheme()
		if button.Parent then
			button.BackgroundColor3 = self._window.Theme.control
			button.BackgroundTransparency = self._window.Theme.controlTransparency
			button.TextColor3 = self._window.Theme.text
			buttonOutline.Color = self._window.Theme.border
			buttonGradient.Color = ColorSequence.new(self._window.Theme.glassTop, self._window.Theme.glassBottom)
		end
	end
	connect(self._window, button.MouseEnter, function() TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = self._window.Theme.controlHover }):Play() end)
	connect(self._window, button.MouseLeave, function() TweenService:Create(button, TweenInfo.new(0.16), { BackgroundColor3 = self._window.Theme.control }):Play() end)
	connect(self._window, button.Activated, function() invoke(options.callback, handle, self._window) end)
	function handle:SetText(text) button.Text = tostring(text or "") end
	function handle:SetCallback(callback) options.callback = callback end
	return handle
end

function Section:Toggle(value)
	local options = asOptions(value)
	local name = options.name or "Toggle"
	local row = makeRow(self, 42, "ToggleRow")
	local hitbox = create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 5 }, row)
	local textLabel = label(row, name, { Size = UDim2.new(1, -66, 1, 0), textSize = 13, color = self._window.Theme.text, zIndex = 6 })
	local track = create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(42, 23),
		BackgroundColor3 = self._window.Theme.control, BackgroundTransparency = 0.28, BorderSizePixel = 0, ZIndex = 7,
	}, row)
	corner(track, 12)
	local trackOutline = outline(track, self._window.Theme.border, 0.62, 1)
	local trackGradient = gradient(track, self._window.Theme.control, self._window.Theme.glassTop, 90, NumberSequence.new(0.48, 0.86))
	refract(self._window, track, 2, true)
	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(17, 17),
		BackgroundColor3 = self._window.Theme.glassTop, BorderSizePixel = 0, ZIndex = 8,
	}, track)
	corner(knob, 9)
	local knobOutline = outline(knob, self._window.Theme.border, 0.48, 1)
	local handle = makeHandle(self, name, row)
	handle.Value = options.default == true
	handle.Callback = options.callback
	handle.Label = textLabel
	handle.Track = track
	handle.Knob = knob
	function handle:RefreshTheme()
		if not track.Parent then return end
		track.BackgroundColor3 = self.Value and self._window.Theme.accent or self._window.Theme.control
		trackOutline.Color = self._window.Theme.border
		trackGradient.Color = self.Value and ColorSequence.new(self._window.Theme.accent, self._window.Theme.accentSecondary)
			or ColorSequence.new(self._window.Theme.control, self._window.Theme.glassTop)
		knob.BackgroundColor3 = self._window.Theme.glassTop
		knobOutline.Color = self._window.Theme.border
		knob.Position = self.Value and UDim2.new(1, -20, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
		textLabel.TextColor3 = self._window.Theme.text
	end
	function handle:Set(nextValue, silent)
		self.Value = nextValue == true
		self:RefreshTheme()
		if not silent then invoke(self.Callback, self.Value, self) end
		return self.Value
	end
	function handle:Get() return self.Value end
	connect(self._window, hitbox.Activated, function() handle:Set(not handle.Value) end)
	handle:RefreshTheme()
	return handle
end

function Section:Slider(value)
	local options = asOptions(value)
	local name = options.name or "Slider"
	local minimum, maximum = tonumber(options.min) or 0, tonumber(options.max) or 100
	if maximum < minimum then minimum, maximum = maximum, minimum end
	local row = makeRow(self, 45, "SliderRow")
	local textLabel = label(row, name, { Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, -70, 0, 19), textSize = 13, color = self._window.Theme.text, zIndex = 6 })
	local valueLabel = label(row, "", { Position = UDim2.new(1, -65, 0, 0), Size = UDim2.fromOffset(65, 19), textSize = 12, color = self._window.Theme.muted, align = Enum.TextXAlignment.Right, zIndex = 6 })
	local track = create("TextButton", {
		Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 7),
		BackgroundColor3 = self._window.Theme.control, BackgroundTransparency = 0.3, BorderSizePixel = 0, AutoButtonColor = false,
		Text = "", ZIndex = 6,
	}, row)
	corner(track, 5)
	local trackOutline = outline(track, self._window.Theme.border, 0.68, 1)
	local trackGradient = gradient(track, self._window.Theme.control, self._window.Theme.glassTop, 90, NumberSequence.new(0.48, 0.88))
	local fill = create("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = self._window.Theme.accent, BorderSizePixel = 0, ZIndex = 7 }, track)
	corner(fill, 5)
	local fillGradient = gradient(fill, self._window.Theme.accent, self._window.Theme.accentSecondary, 0, NumberSequence.new(0.05, 0.38))
	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(13, 13),
		BackgroundColor3 = self._window.Theme.glassTop, BorderSizePixel = 0, ZIndex = 8,
	}, track)
	corner(knob, 7)
	refract(self._window, knob, 2, true)
	local knobOutline = outline(knob, self._window.Theme.border, 0.4, 1)
	local handle = makeHandle(self, name, row)
	handle.Min, handle.Max = minimum, maximum
	handle.Step = tonumber(options.step) or 1
	handle.Suffix = options.suffix or ""
	handle.Value = math.clamp(tonumber(options.default) or minimum, minimum, maximum)
	handle.Callback = options.callback
	function handle:RefreshTheme()
		if not row.Parent then return end
		fill.BackgroundColor3 = self._window.Theme.accent
		fillGradient.Color = ColorSequence.new(self._window.Theme.accent, self._window.Theme.accentSecondary)
		knob.BackgroundColor3 = self._window.Theme.glassTop
		knobOutline.Color = self._window.Theme.border
		track.BackgroundColor3 = self._window.Theme.control
		trackOutline.Color = self._window.Theme.border
		trackGradient.Color = ColorSequence.new(self._window.Theme.control, self._window.Theme.glassTop)
		textLabel.TextColor3 = self._window.Theme.text
		valueLabel.TextColor3 = self._window.Theme.muted
	end
	local function render()
		local range = maximum - minimum
		local fraction = range == 0 and 0 or math.clamp((handle.Value - minimum) / range, 0, 1)
		fill.Size = UDim2.new(fraction, 0, 1, 0)
		knob.Position = UDim2.new(fraction, 0, 0.5, 0)
		valueLabel.Text = tostring(handle.Value) .. handle.Suffix
		handle:RefreshTheme()
	end
	function handle:Set(nextValue, silent)
		local number = math.clamp(tonumber(nextValue) or minimum, minimum, maximum)
		local step = self.Step > 0 and self.Step or 1
		self.Value = minimum + math.floor((number - minimum) / step + 0.5) * step
		self.Value = math.clamp(self.Value, minimum, maximum)
		render()
		if not silent then invoke(self.Callback, self.Value, self) end
		return self.Value
	end
	function handle:Get() return self.Value end
	local dragging = false
	local function updateFromPointer()
		local pointer = guiPointer(self._window)
		local fraction = math.clamp((pointer.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		handle:Set(minimum + (maximum - minimum) * fraction)
	end
	connect(self._window, track.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true; updateFromPointer() end
	end)
	connect(self._window, self._window.Gui:GetPropertyChangedSignal("Enabled"), function() if not self._window.Gui.Enabled then dragging = false end end)
	connect(self._window, UserInputService.InputChanged, function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then updateFromPointer() end
	end)
	connect(self._window, UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
	function handle:SetVisible(visible) self.Row.Visible = visible ~= false end
	render()
	return handle
end

function Section:Dropdown(value)
	local options = asOptions(value)
	local name = options.name or "Dropdown"
	local items = options.items or options.values or {}
	local row = create("Frame", { Name = "DropdownRow", Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, ZIndex = 5 }, self.Content)
	local main = create("Frame", { Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, ZIndex = 5 }, row)
	local nameLabel = label(main, name, { Size = UDim2.new(0.47, -4, 1, 0), textSize = 13, color = self._window.Theme.text, zIndex = 6 })
	local choice = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0.53, 0, 0, 30),
		BackgroundColor3 = self._window.Theme.control, BackgroundTransparency = self._window.Theme.controlTransparency, BorderSizePixel = 0,
		AutoButtonColor = false, Text = "", ZIndex = 6,
	}, main)
	corner(choice, 15)
	local choiceOutline = outline(choice, self._window.Theme.border, 0.58, 1)
	local choiceGradient = gradient(choice, self._window.Theme.glassTop, self._window.Theme.glassBottom, 95, NumberSequence.new(0.48, 0.9))
	refract(self._window, choice, 2, true)
	local handle = makeHandle(self, name, row)
	handle.Items = items
	handle.Value = options.default or items[1]
	handle.Callback = options.callback
	local choiceLabel = label(choice, tostring(handle.Value or "Select"), { Position = UDim2.fromOffset(9, 0), Size = UDim2.new(1, -27, 1, 0), textSize = 12, color = self._window.Theme.text, zIndex = 7 })
	local arrow = label(choice, "⌄", { Position = UDim2.new(1, -23, 0, 0), Size = UDim2.fromOffset(17, 30), textSize = 14, color = self._window.Theme.muted, align = Enum.TextXAlignment.Center, zIndex = 7 })
	local list = create("Frame", { Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 8 }, row)
	local listLayout = create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	local expanded = false
	local function updateTheme()
		choice.BackgroundColor3 = self._window.Theme.control
		choice.BackgroundTransparency = self._window.Theme.controlTransparency
		nameLabel.TextColor3 = self._window.Theme.text
		choiceOutline.Color = self._window.Theme.border
		choiceGradient.Color = ColorSequence.new(self._window.Theme.glassTop, self._window.Theme.glassBottom)
		choiceLabel.TextColor3 = self._window.Theme.text
		arrow.TextColor3 = self._window.Theme.muted
		for _, itemButton in ipairs(list:GetChildren()) do
			if itemButton:IsA("TextButton") then
				itemButton.BackgroundColor3 = self._window.Theme.control
				itemButton.TextColor3 = self._window.Theme.text
				local itemGradient = itemButton:FindFirstChildOfClass("UIGradient")
				if itemGradient then itemGradient.Color = materialColors(self._window.Theme) end
			end
		end
	end
	local function set(nextValue, silent)
		handle.Value = nextValue
		choiceLabel.Text = tostring(nextValue or "Select")
		list.Visible = false
		expanded = false
		row.Size = UDim2.new(1, 0, 0, 42)
		if not silent then invoke(handle.Callback, handle.Value, handle) end
	end
	function handle:Set(nextValue, silent) set(nextValue, silent) return handle.Value end
	function handle:Get() return handle.Value end
	function handle:SetItems(nextItems)
		items = nextItems or {}
		handle.Items = items
		for _, child in ipairs(list:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
		for index, item in ipairs(items) do
			local itemButton = create("TextButton", {
				Name = "Option_" .. tostring(index), Size = UDim2.new(1, 0, 0, 28),
				BackgroundColor3 = self._window.Theme.control, BackgroundTransparency = 0.38,
				BorderSizePixel = 0, AutoButtonColor = false, Text = tostring(item),
				Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = self._window.Theme.text,
				ZIndex = 9, LayoutOrder = index,
			}, list)
			corner(itemButton, 9)
			gradient(itemButton, self._window.Theme.glassTop, self._window.Theme.glassBottom, 90, NumberSequence.new(0.5, 0.9))
			connect(self._window, itemButton.Activated, function() set(item) end)
		end
		list.Size = UDim2.new(1, 0, 0, math.min(#items, 5) * 28 + math.max(0, math.min(#items, 5) - 1) * 4)
	end
	connect(self._window, choice.Activated, function()
		expanded = not expanded
		list.Visible = expanded
		row.Size = UDim2.new(1, 0, 0, expanded and (46 + list.Size.Y.Offset) or 42)
	end)
	connect(self._window, self._window.Gui:GetPropertyChangedSignal("Enabled"), function() if not self._window.Gui.Enabled then list.Visible = false; expanded = false end end)
	handle.RefreshTheme = updateTheme
	themeBinding(self._window, updateTheme)
	handle:SetItems(items)
	return handle
end

function Section:Textbox(value)
	local options = asOptions(value)
	local name = options.name or "Textbox"
	local row = makeRow(self, 42, "TextboxRow")
	local nameLabel = label(row, name, { Size = UDim2.new(0.44, 0, 1, 0), textSize = 13, color = self._window.Theme.text, zIndex = 6 })
	local box = create("TextBox", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0.54, 0, 0, 30),
		BackgroundColor3 = self._window.Theme.control, BackgroundTransparency = self._window.Theme.controlTransparency, BorderSizePixel = 0,
		ClearTextOnFocus = false, Text = tostring(options.default or ""), PlaceholderText = options.placeholder or "Enter text",
		Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = self._window.Theme.text, PlaceholderColor3 = self._window.Theme.muted,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
	}, row)
	corner(box, 15)
	local boxOutline = outline(box, self._window.Theme.border, 0.58, 1)
	local boxGradient = gradient(box, self._window.Theme.glassTop, self._window.Theme.glassBottom, 95, NumberSequence.new(0.5, 0.9))
	refract(self._window, box, 2, true)
	create("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 8) }, box)
	local handle = makeHandle(self, name, row)
	handle.Input = box
	handle.Value = box.Text
	handle.Callback = options.callback
	function handle:Set(text, silent)
		self.Value = tostring(text or "")
		box.Text = self.Value
		if not silent then invoke(self.Callback, self.Value, self) end
		return self.Value
	end
	function handle:Get() return box.Text end
	function handle:RefreshTheme()
		if box.Parent then
			box.BackgroundColor3 = self._window.Theme.control
			box.BackgroundTransparency = self._window.Theme.controlTransparency
			box.TextColor3 = self._window.Theme.text
			box.PlaceholderColor3 = self._window.Theme.muted
			boxOutline.Color = self._window.Theme.border
			boxGradient.Color = ColorSequence.new(self._window.Theme.glassTop, self._window.Theme.glassBottom)
			nameLabel.TextColor3 = self._window.Theme.text
		end
	end
	connect(self._window, box.FocusLost, function()
		handle.Value = box.Text
		invoke(handle.Callback, handle.Value, handle)
	end)
	return handle
end

function Section:Keybind(value)
	local options = asOptions(value)
	local name = options.name or "Keybind"
	local row = makeRow(self, 42, "KeybindRow")
	local nameLabel = label(row, name, { Size = UDim2.new(1, -105, 1, 0), textSize = 13, color = self._window.Theme.text, zIndex = 6 })
	local button = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(94, 28),
		BackgroundColor3 = self._window.Theme.control, BackgroundTransparency = self._window.Theme.controlTransparency, BorderSizePixel = 0,
		AutoButtonColor = false, Text = "", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = self._window.Theme.text,
		ZIndex = 6,
	}, row)
	corner(button, 14)
	local buttonOutline = outline(button, self._window.Theme.border, 0.58, 1)
	local buttonGradient = gradient(button, self._window.Theme.glassTop, self._window.Theme.glassBottom, 95, NumberSequence.new(0.48, 0.9))
	refract(self._window, button, 2, true)
	local handle = makeHandle(self, name, row)
	handle.Value = normalizeKey(options.default or options.key or Enum.KeyCode.Unknown)
	handle.Callback = options.callback
	handle.Button = button
	local function render() button.Text = self._window._listeningKeybind == handle and "Press a key…" or handle.Value.Name end
	function handle:Set(key, silent)
		self.Value = normalizeKey(key)
		render()
		if not silent then invoke(self.Callback, self.Value, self) end
		return self.Value
	end
	function handle:Get() return self.Value end
	function handle:RefreshTheme()
		if button.Parent then
			button.BackgroundColor3 = self._window.Theme.control
			button.BackgroundTransparency = self._window.Theme.controlTransparency
			button.TextColor3 = self._window.Theme.text
			buttonOutline.Color = self._window.Theme.border
			buttonGradient.Color = ColorSequence.new(self._window.Theme.glassTop, self._window.Theme.glassBottom)
			nameLabel.TextColor3 = self._window.Theme.text
		end
	end
	connect(self._window, button.Activated, function() self._window._listeningKeybind = handle; render() end)
	connect(self._window, button.MouseEnter, function() button.BackgroundColor3 = self._window.Theme.controlHover end)
	connect(self._window, button.MouseLeave, function() button.BackgroundColor3 = self._window.Theme.control end)
	return handle
end

function Section:Colorpicker(value)
	local options = asOptions(value)
	local name = options.name or "Color"
	local row = makeRow(self, 35, "ColorpickerRow")
	local nameLabel = label(row, name, { Size = UDim2.new(1, -70, 1, 0), textSize = 13, color = self._window.Theme.text, zIndex = 6 })
	local swatch = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(48, 24),
		BackgroundColor3 = options.color or Color3.fromRGB(131, 199, 255), BackgroundTransparency = 1 - (options.alpha or 1),
		BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 6,
	}, row)
	corner(swatch, 9)
	local swatchOutline = outline(swatch, self._window.Theme.border, 0.34, 1)
	local handle = makeHandle(self, name, row)
	local hue, saturation, brightness = (options.color or self._window.Theme.accent):ToHSV()
	handle.Color = options.color or self._window.Theme.accent
	handle.Alpha = math.clamp(tonumber(options.alpha) or 1, 0, 1)
	handle.Callback = options.callback
	function handle:Get() return { color = self.Color, alpha = self.Alpha } end
	function handle:Set(color, alpha, silent)
		if type(color) == "table" then alpha = color.alpha or color[2] or alpha; color = color.color or color[1] end
		if typeof(color) ~= "Color3" then return self:Get() end
		self.Color = color
		self.Alpha = math.clamp(tonumber(alpha) or self.Alpha, 0, 1)
		hue, saturation, brightness = color:ToHSV()
		swatch.BackgroundColor3 = color
		swatch.BackgroundTransparency = 1 - self.Alpha
		local refs = self._popupRefs
		if refs and refs.Frame.Parent then
			refs.Square.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
			refs.WhiteGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHSV(hue, 1, 1))
			refs.Marker.Position = UDim2.fromScale(saturation, 1 - brightness)
			refs.HueMarker.Position = UDim2.new(0.5, 0, hue, 0)
			refs.Hex.Text = "#" .. color:ToHex()
			refs.AlphaFill.Size = UDim2.new(self.Alpha, 0, 1, 0)
		end
		if not silent then invoke(self.Callback, self.Color, self.Alpha, self) end
		return self:Get()
	end
	function handle:RefreshTheme()
		if swatch.Parent then
			swatchOutline.Color = self._window.Theme.border
			nameLabel.TextColor3 = self._window.Theme.text
		end
		local refs = self._popupRefs
		if refs and refs.Frame.Parent then
			refs.Outline.Color = self._window.Theme.border
			refs.Frame.BackgroundColor3 = Color3.new(1, 1, 1)
			refs.Gradient.Color = materialColors(self._window.Theme)
			refs.Title.TextColor3 = self._window.Theme.text
			refs.Opacity.TextColor3 = self._window.Theme.muted
			refs.Hex.TextColor3 = self._window.Theme.text
			refs.AlphaTrack.BackgroundColor3 = self._window.Theme.control
			refs.AlphaFill.BackgroundColor3 = self._window.Theme.accent
		end
	end
	local function closePopup()
		local popupState = self._window._popup
		if popupState then
			if popupState.Connections then for _, connection in ipairs(popupState.Connections) do connection:Disconnect() end end
			if popupState.Frame then popupState.Frame:Destroy() end
			self._window._popup = nil
			if popupState.Owner then popupState.Owner._popupRefs = nil end
		end
	end
	local function openPopup()
		if self._window._popup and self._window._popup.Owner == handle then closePopup(); return end
		closePopup()
		local popup = create("Frame", {
			Name = "ColorPickerGlass",
			Size = UDim2.fromOffset(226, 205),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.36,
			BorderSizePixel = 0,
			ZIndex = 40,
		}, self._window.Gui)
		corner(popup, 15)
		local popupOutline = outline(popup, self._window.Theme.border, 0.3, 1.2)
		local popupGradient = gradient(popup, self._window.Theme.glassTop, self._window.Theme.glassBottom, 105, NumberSequence.new(0.22, 0.56))
		refract(self._window, popup, 3)
		local pos = swatch.AbsolutePosition
		local view = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1024, 768)
		local x = math.clamp(pos.X - 178, 8, math.max(8, view.X - 234))
		local y = math.clamp(pos.Y + 30, 8, math.max(8, view.Y - 213))
		popup.Position = UDim2.fromOffset(x, y)
		local popupTitle = label(popup, name, { Position = UDim2.fromOffset(12, 5), Size = UDim2.new(1, -24, 0, 22), textSize = 12, font = Enum.Font.GothamSemibold, color = self._window.Theme.text, zIndex = 42 })
		local square = create("TextButton", {
			Name = "SaturationValue", Position = UDim2.fromOffset(12, 33), Size = UDim2.fromOffset(155, 112),
			BackgroundColor3 = Color3.fromHSV(hue, 1, 1), BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 42,
		}, popup)
		corner(square, 8)
		local white = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 43 }, square)
		corner(white, 8)
		local whiteGradient = gradient(white, Color3.new(1, 1, 1), Color3.fromHSV(hue, 1, 1), 0, NumberSequence.new(0, 0))
		local black = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 44 }, square)
		corner(black, 8)
		gradient(black, Color3.new(0, 0, 0), Color3.new(0, 0, 0), 90, NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }))
		local marker = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(saturation, 1 - brightness), Size = UDim2.fromOffset(9, 9),
			BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 46,
		}, square)
		corner(marker, 5)
		outline(marker, Color3.new(1, 1, 1), 0, 1)
		local hueBar = create("TextButton", {
			Name = "Hue", Position = UDim2.fromOffset(178, 33), Size = UDim2.fromOffset(18, 112),
			BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 42,
		}, popup)
		corner(hueBar, 7)
		create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
				ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
				ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
				ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
			}),
		}, hueBar)
		local hueMarker = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, hue, 0), Size = UDim2.new(1, 4, 0, 3),
			BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 44,
		}, hueBar)
		local alphaTrack = create("TextButton", {
			Name = "Opacity", Position = UDim2.fromOffset(12, 165), Size = UDim2.new(1, -24, 0, 5),
			BackgroundColor3 = self._window.Theme.control, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 42,
		}, popup)
		corner(alphaTrack, 4)
		local alphaFill = create("Frame", { Size = UDim2.new(handle.Alpha, 0, 1, 0), BackgroundColor3 = self._window.Theme.accent, BorderSizePixel = 0, ZIndex = 43 }, alphaTrack)
		corner(alphaFill, 4)
		local opacityLabel = label(popup, "Opacity", { Position = UDim2.fromOffset(12, 174), Size = UDim2.fromOffset(60, 20), textSize = 9, color = self._window.Theme.muted, zIndex = 42 })
		local hex = label(popup, "#" .. handle.Color:ToHex(), { Position = UDim2.new(1, -94, 1, -29), Size = UDim2.fromOffset(82, 20), textSize = 9, color = self._window.Theme.text, align = Enum.TextXAlignment.Right, zIndex = 42 })
		local mode
		local function updateColor()
			local color = Color3.fromHSV(hue, saturation, brightness)
			handle:Set(color, handle.Alpha)
			square.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
			whiteGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHSV(hue, 1, 1))
			marker.Position = UDim2.fromScale(saturation, 1 - brightness)
			hueMarker.Position = UDim2.new(0.5, 0, hue, 0)
			hex.Text = "#" .. color:ToHex()
		end
		local function updatePointer(input)
			local point = guiPointer(self._window)
			if input and input.UserInputType == Enum.UserInputType.Touch then
				point = Vector2.new(input.Position.X, input.Position.Y)
			end
			if mode == "sv" then
				saturation = math.clamp((point.X - square.AbsolutePosition.X) / square.AbsoluteSize.X, 0, 1)
				brightness = 1 - math.clamp((point.Y - square.AbsolutePosition.Y) / square.AbsoluteSize.Y, 0, 1)
			elseif mode == "hue" then
				hue = math.clamp((point.Y - hueBar.AbsolutePosition.Y) / hueBar.AbsoluteSize.Y, 0, 1)
			elseif mode == "alpha" then
				handle.Alpha = math.clamp((point.X - alphaTrack.AbsolutePosition.X) / alphaTrack.AbsoluteSize.X, 0, 1)
				alphaFill.Size = UDim2.new(handle.Alpha, 0, 1, 0)
			end
			updateColor()
		end
		local connections = {}
		local function start(target, selectedMode)
			target.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					mode = selectedMode
					updatePointer(input)
				end
			end)
		end
		start(square, "sv")
		start(hueBar, "hue")
		start(alphaTrack, "alpha")
		table.insert(connections, UserInputService.InputChanged:Connect(function(input)
			if mode and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then updatePointer(input) end
		end))
		table.insert(connections, UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then mode = nil end
		end))
		handle._popupRefs = {
			Frame = popup, Outline = popupOutline, Gradient = popupGradient, Title = popupTitle,
			Opacity = opacityLabel, Hex = hex, AlphaTrack = alphaTrack, AlphaFill = alphaFill,
			Square = square, WhiteGradient = whiteGradient, Marker = marker, HueMarker = hueMarker,
		}
		self._window._popup = { Owner = handle, Frame = popup, Connections = connections }
		handle:RefreshTheme()
	end
	connect(self._window, swatch.Activated, openPopup)
	local baseDestroy = handle.Destroy
	function handle:Destroy()
		if self._window._popup and self._window._popup.Owner == self then closePopup() end
		baseDestroy(self)
	end
	return handle
end

function Section:AddButton(value) return self:Button(value) end
function Section:AddToggle(value) return self:Toggle(value) end
function Section:AddSlider(value) return self:Slider(value) end
function Section:AddDropdown(value) return self:Dropdown(value) end
function Section:AddTextbox(value) return self:Textbox(value) end
function Section:AddColorpicker(value) return self:Colorpicker(value) end
function Section:AddKeybind(value) return self:Keybind(value) end
function Section:AddLabel(value) return self:Label(value) end

function LiquidGlassUI:Notify(message, duration, kind)
	local theme = self.Theme
	local toast = create("Frame", {
		Name = "GlassNotification",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, 70),
		Size = UDim2.fromOffset(290, 58),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.34,
		BorderSizePixel = 0,
		ZIndex = 100,
	}, self.Gui)
	corner(toast, 15)
	outline(toast, theme.border, 0.32, 1.2)
	local toastGradient = gradient(toast, theme.glassTop, theme.glassBottom, 100, NumberSequence.new(0.24, 0.56))
	toastGradient.Color = materialColors(theme)
	refract(self, toast, 3)
	local tint = kind == "success" and theme.positive or (kind == "error" and theme.negative or theme.accent)
	local accentBar = create("Frame", { Position = UDim2.fromOffset(10, 11), Size = UDim2.fromOffset(3, 36), BackgroundColor3 = tint, BorderSizePixel = 0, ZIndex = 102 }, toast)
	corner(accentBar, 2)
	label(toast, tostring(message or ""), { Position = UDim2.fromOffset(22, 8), Size = UDim2.new(1, -32, 1, -16), textSize = 13, color = theme.text, wrapped = true, zIndex = 102 })
	TweenService:Create(toast, TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new(1, -18, 1, -18) }):Play()
	task.delay(duration or 3, function()
		if toast.Parent then
			local tween = TweenService:Create(toast, TweenInfo.new(0.2), { Position = UDim2.new(1, -18, 1, 70), BackgroundTransparency = 1 })
			tween:Play()
			tween.Completed:Wait()
			if toast.Parent then toast:Destroy() end
		end
	end)
	return toast
end

function LiquidGlassUI:Destroy(fromGui)
	if self._destroyed then return end
	self._destroyed = true
	if self._renderer then self._renderer:Destroy(); self._renderer = nil end
	for _, target in pairs(self._refractionTargets) do if target.Connection then target.Connection:Disconnect() end end
	table.clear(self._refractionTargets)
	if self._blurTween then self._blurTween:Cancel() end
	if self._blurEffect then self._blurEffect:Destroy(); self._blurEffect = nil end
	if self._popup then
		for _, connection in ipairs(self._popup.Connections or {}) do connection:Disconnect() end
		if self._popup.Frame then self._popup.Frame:Destroy() end
		self._popup = nil
	end
	for _, connection in ipairs(self._connections) do connection:Disconnect() end
	table.clear(self._connections)
	table.clear(self._themeUpdaters)
	if not fromGui and self.Gui and self.Gui.Parent then self.Gui:Destroy() end
end

LiquidGlassUI.window = LiquidGlassUI.new
LiquidGlassUI.create = LiquidGlassUI.new

return LiquidGlassUI
