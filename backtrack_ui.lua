--[=[
    Backtrack UI
    A standalone, executor-independent Roblox/Luau UI toolkit.

    The package contains UI primitives only. Applications own their game logic,
    persistence, and permission checks and pass those through callbacks.
]=]

local BacktrackUI = {}
BacktrackUI.__index = BacktrackUI
local createSection
local Column

BacktrackUI.Version = "1.6.1"
BacktrackUI.Theme = {
	outline = Color3.fromRGB(10, 10, 10),
	inline = Color3.fromRGB(34, 34, 34),
	background = Color3.fromRGB(16, 16, 16),
	surface = Color3.fromRGB(16, 16, 16),
	surfaceHover = Color3.fromRGB(28, 28, 37),
	border = Color3.fromRGB(34, 34, 34),
	text = Color3.fromRGB(224, 224, 224),
	muted = Color3.fromRGB(160, 160, 166),
	accent = Color3.fromRGB(255, 98, 127),
	high_contrast = Color3.fromRGB(13, 13, 13),
	low_contrast = Color3.fromRGB(16, 16, 16),
	text_outline = Color3.fromRGB(0, 0, 0),
	contrastTop = Color3.fromRGB(41, 41, 55),
	contrastBottom = Color3.fromRGB(35, 35, 47),
	glow = Color3.fromRGB(255, 98, 127),
	positive = Color3.fromRGB(122, 255, 117),
	negative = Color3.fromRGB(255, 117, 129),
	information = Color3.fromRGB(154, 135, 254),
	warning = Color3.fromRGB(247, 215, 98),
}

local cloneReference = cloneref or clonereference
local function getService(name)
	local service = game:GetService(name)
	if type(cloneReference) == "function" then
		local ok, reference = pcall(cloneReference, service)
		if ok and reference then return reference end
	end
	return service
end

local Players = getService("Players")
local UserInputService = getService("UserInputService")
local GuiService = getService("GuiService")
local TweenService = getService("TweenService")
local RunService = getService("RunService")
local getHiddenGui = gethui or get_hidden_gui
local GuiThemes = setmetatable({}, { __mode = "k" })
local cursorBindingCounter = 0

local function mergeTheme(overrides, base)
	local theme = {}
	for key, value in pairs(BacktrackUI.Theme) do
		theme[key] = value
	end
	for key, value in pairs(base or {}) do
		theme[key] = value
	end
	for key, value in pairs(overrides or {}) do
		theme[key] = value
	end
	return theme
end

local function applyThemeChanges(self)
	local previous = self._appliedTheme or {}
	local nextTheme = self.Theme
	local changedColors = {}
	local function replacementFor(color)
		for _, change in ipairs(changedColors) do
			if color == change.old then return change.new end
		end
		return nil
	end
	local fontChanged = previous.fontFace ~= nextTheme.fontFace
	local contrastChanged = previous.contrastTop ~= nextTheme.contrastTop or previous.contrastBottom ~= nextTheme.contrastBottom
	for key, oldColor in pairs(previous) do
		local newColor = nextTheme[key]
		if oldColor ~= newColor and typeof(oldColor) == "Color3" and typeof(newColor) == "Color3" then
			table.insert(changedColors, { old = oldColor, new = newColor })
		end
	end

	local hasColorChanges = #changedColors > 0
	if not hasColorChanges and not fontChanged and not contrastChanged then
		self._appliedTheme = mergeTheme(nextTheme)
		return
	end

	local themeGuis = { self.Gui }
	if self.OverlayGui then table.insert(themeGuis, self.OverlayGui) end
	for _, watermark in ipairs(self._watermarks) do
		if watermark.Gui and watermark.Gui.Parent then table.insert(themeGuis, watermark.Gui) end
	end
	for _, panel in ipairs(self._panels) do
		if panel.Gui and panel.Gui.Parent then table.insert(themeGuis, panel.Gui) end
	end
	local textClasses = { TextLabel = true, TextButton = true, TextBox = true }
	for _, gui in ipairs(themeGuis) do
		GuiThemes[gui] = nextTheme
		for _, object in ipairs(gui:GetDescendants()) do
			if fontChanged and (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")) then
				if nextTheme.fontFace then
					pcall(function() object.FontFace = nextTheme.fontFace end)
				else
					pcall(function() object.Font = Enum.Font.Legacy end)
				end
			end
			if contrastChanged and object:IsA("UIGradient") and object.Name == "ThemeGradient" then
				object.Color = ColorSequence.new(nextTheme.contrastTop, nextTheme.contrastBottom)
			end
			if hasColorChanges then
				if object:IsA("UIStroke") then
					local replacement = replacementFor(object.Color)
					if replacement then object.Color = replacement end
				elseif object:IsA("GuiObject") then
					local replacement = replacementFor(object.BackgroundColor3)
					if replacement then object.BackgroundColor3 = replacement end
					replacement = replacementFor(object.BorderColor3)
					if replacement then object.BorderColor3 = replacement end
					if textClasses[object.ClassName] then
						replacement = replacementFor(object.TextColor3)
						if replacement then object.TextColor3 = replacement end
						replacement = replacementFor(object.TextStrokeColor3)
						if replacement then object.TextStrokeColor3 = replacement end
					end
					if object:IsA("ImageLabel") or object:IsA("ImageButton") then
						replacement = replacementFor(object.ImageColor3)
						if replacement then object.ImageColor3 = replacement end
					end
					if object:IsA("ScrollingFrame") then
						replacement = replacementFor(object.ScrollBarImageColor3)
						if replacement then object.ScrollBarImageColor3 = replacement end
					end
				end
			end
		end
	end
	self._appliedTheme = mergeTheme(nextTheme)
end

local function create(className, properties, parent)
	local object = Instance.new(className)
	for key, value in pairs(properties or {}) do
		object[key] = value
	end
	object.Parent = parent
	if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
		local ancestor = parent
		while ancestor do
			local theme = GuiThemes[ancestor]
			if theme then
				if theme.fontFace then pcall(function() object.FontFace = theme.fontFace end) end
				break
			end
			ancestor = ancestor.Parent
		end
	end
	return object
end

local function corner(parent, radius)
	-- The reference UI uses hard corners throughout.
	return nil
end

local function gradient(parent, topColor, bottomColor, rotation)
	return create("UIGradient", {
		Name = "ThemeGradient",
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, topColor),
			ColorSequenceKeypoint.new(1, bottomColor),
		}),
		Rotation = rotation or 90,
	}, parent)
end

local function stroke(parent, color, thickness, transparency)
	return create("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function themeRole(theme, color)
	for role, value in pairs(theme) do
		if value == color then return role end
	end
	return nil
end

local function label(parent, text, theme, options)
	options = options or {}
	return create("TextLabel", {
		Name = options.name or "Label",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = options.size or UDim2.new(1, 0, 0, options.height or 20),
		Position = options.position or UDim2.new(),
		AnchorPoint = options.anchorPoint or Vector2.zero,
		Font = options.font or Enum.Font.Legacy,
		Text = tostring(text or ""),
		TextColor3 = options.color or theme.text,
		TextStrokeColor3 = options.textStrokeColor or theme.text_outline,
		TextStrokeTransparency = options.textStrokeTransparency or 1,
		TextTransparency = options.textTransparency or 0,
		TextSize = options.textSize or 12,
		TextXAlignment = options.align or Enum.TextXAlignment.Left,
		TextYAlignment = options.valign or Enum.TextYAlignment.Center,
		TextWrapped = options.wrapped or false,
		TextTruncate = options.truncate and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None,
		AutomaticSize = options.automaticSize or Enum.AutomaticSize.None,
		ZIndex = options.zIndex or 2,
	}, parent)
end

local function button(parent, text, theme, options)
	options = options or {}
	local baseColor = options.background or theme.surface
	local hoverColor = options.hoverColor or theme.surfaceHover
	local baseRole = themeRole(theme, baseColor)
	local hoverRole = themeRole(theme, hoverColor)
	local control = create("TextButton", {
		Name = options.name or "Button",
		AutoButtonColor = false,
		BackgroundColor3 = baseColor,
		BorderSizePixel = 0,
		Size = options.size or UDim2.new(1, 0, 0, options.height or 24),
		Position = options.position or UDim2.new(),
		AnchorPoint = options.anchorPoint or Vector2.zero,
		Font = options.font or Enum.Font.Legacy,
		Text = tostring(text or ""),
		TextColor3 = options.color or theme.text,
		TextStrokeColor3 = theme.text_outline,
		TextStrokeTransparency = 0.3,
		TextSize = options.textSize or 11,
		TextXAlignment = options.align or Enum.TextXAlignment.Center,
		ZIndex = options.zIndex or 2,
	}, parent)
	corner(control, options.radius or 0)
	if options.stroke ~= false then
		stroke(control, options.border or theme.border, 1)
	end
	control.MouseEnter:Connect(function()
		if options.hover ~= false then
			control.BackgroundColor3 = (hoverRole and theme[hoverRole]) or hoverColor
		end
	end)
	control.MouseLeave:Connect(function()
		control.BackgroundColor3 = (baseRole and theme[baseRole]) or baseColor
	end)
	return control
end

local function sourceActionButton(parent, text, theme, options)
	options = options or {}
	local control = create("TextButton", {
		Name = options.name or "Button",
		AutoButtonColor = options.autoButtonColor == true,
		BackgroundColor3 = options.buttonColor or options.backgroundColor or theme.outline,
		BorderSizePixel = options.borderSizePixel or 0,
		Position = options.position or UDim2.new(),
		Size = options.size or UDim2.new(1, 0, 0, 18),
		Text = "",
		ZIndex = options.zIndex or 2,
	}, parent)
	local inline = create("Frame", {
		Name = "Inline",
		Position = options.inlinePosition or UDim2.fromOffset(1, 1),
		Size = options.inlineSize or UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = options.inlineColor or theme.inline,
		BorderSizePixel = 0,
		ZIndex = control.ZIndex + 1,
	}, control)
	local accent = create("Frame", {
		Name = "Accent",
		Position = options.accentPosition or UDim2.fromOffset(1, 1),
		Size = options.accentSize or UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = options.accentColor or theme.accent,
		BorderSizePixel = 0,
		ZIndex = control.ZIndex + 1,
	}, inline)
	gradient(accent, options.accentTopColor or Color3.fromRGB(255, 255, 255), options.accentBottomColor or Color3.fromRGB(167, 167, 167))
	local face = create("Frame", {
		Name = "Face",
		Position = options.surfacePosition or UDim2.new(),
		Size = options.surfaceSize or UDim2.fromScale(1, 1),
		BackgroundColor3 = options.surfaceColor or theme.contrastTop,
		BorderSizePixel = 0,
		ZIndex = control.ZIndex + 1,
	}, accent)
	gradient(face, options.surfaceColor or theme.contrastTop, options.surfaceBottomColor or theme.contrastBottom)
	local title = label(face, text, theme, {
		name = "Title",
		position = UDim2.new(0, 4, 0, -1),
		size = UDim2.new(1, -4, 1, 0),
		textSize = options.textSize or 12,
		align = options.align or Enum.TextXAlignment.Center,
		color = options.textColor or theme.text,
		textStrokeColor = options.textStrokeColor,
		textStrokeTransparency = options.textStrokeTransparency,
		textTransparency = options.textTransparency,
		font = options.font,
		wrapped = true,
		truncate = true,
		zIndex = control.ZIndex + 2,
	})
	create("UIStroke", { LineJoinMode = Enum.LineJoinMode.Miter }, title)
	local fill = create("Frame", {
		Name = "HoverFill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = options.hoverColor or theme.accent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = control.ZIndex + 1,
	}, accent)
	gradient(fill, Color3.fromRGB(255, 255, 255), Color3.fromRGB(117, 117, 117))
	control.MouseEnter:Connect(function()
		if options.hover ~= false then
			TweenService:Create(fill, TweenInfo.new(options.hoverDuration or 0.12), {
				BackgroundTransparency = options.hoverTransparency or 0.15,
			}):Play()
		end
	end)
	control.MouseLeave:Connect(function()
		TweenService:Create(fill, TweenInfo.new(options.hoverDuration or 0.12), {
			BackgroundTransparency = options.restTransparency or 1,
		}):Play()
	end)
	return control
end

local function connect(window, signal, callback)
	local connection = signal:Connect(callback)
	table.insert(window._connections, connection)
	return connection
end

local function makeResizable(window, frame)
	local handle = create("TextButton", {
		Name = "ResizeHandle",
		Position = UDim2.new(1, -10, 1, -10),
		Size = UDim2.fromOffset(10, 10),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 100,
	}, frame)
	local startPosition, startSize
	connect(window, handle.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			startPosition = input.Position
			startSize = frame.Size
		end
	end)
	connect(window, UserInputService.InputChanged, function(input)
		if startPosition and startSize and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - startPosition
			frame.Size = UDim2.fromOffset(math.max(180, startSize.X.Offset + delta.X), math.max(140, startSize.Y.Offset + delta.Y))
		end
	end)
	connect(window, UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			startPosition, startSize = nil, nil
		end
	end)
	return handle
end

local function invoke(callback, ...)
	if type(callback) ~= "function" then
		return
	end
	local ok, err = pcall(callback, ...)
	if not ok then
		warn("[BacktrackUI] callback error: " .. tostring(err))
	end
end

local function normalizeFlag(name, index)
	local source = tostring(name or "control"):lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
	if source == "" then
		source = "control"
	end
	return source .. "_" .. tostring(index)
end

local function copyValue(value)
	if type(value) == "table" then
		local copy = {}
		for key, item in pairs(value) do
			copy[key] = item
		end
		return copy
	end
	return value
end

local function keyName(key)
	if key == nil then return "None" end
	if typeof(key) == "EnumItem" then return key.Name end
	local text = tostring(key)
	text = text:gsub("Enum%.KeyCode%.", ""):gsub("Enum%.UserInputType%.", "")
	return text
end

local function inputMatches(input, key)
	if key == nil then return false end
	if typeof(key) == "EnumItem" then
		return input.KeyCode == key or input.UserInputType == key
	end
	local name = keyName(key)
	return input.KeyCode.Name == name or input.UserInputType.Name == name
end

local function normalizeMode(mode)
	local name = tostring(mode or "Toggle"):lower()
	local modes = { toggle = "Toggle", hold = "Hold", always = "Always", never = "Never" }
	return modes[name] or "Toggle"
end

function BacktrackUI.new(options)
	options = options or {}
	cursorBindingCounter = cursorBindingCounter + 1
	local player = Players.LocalPlayer
	local parent = options.parent
	if not parent then
		if type(getHiddenGui) == "function" then
			local ok, hiddenGui = pcall(getHiddenGui)
			if ok then parent = hiddenGui end
		end
		if not parent then
			assert(player, "BacktrackUI.new requires options.parent outside a LocalPlayer context")
			parent = player:WaitForChild("PlayerGui")
		end
	end

	local self = setmetatable({
		Theme = mergeTheme(options.theme),
		_appliedTheme = mergeTheme(options.theme),
		Images = options.images or {},
		_Connections = {},
		_connections = {},
		_controls = {},
		_flags = {},
		_values = {},
		_tabs = {},
		_panels = {},
		_luaModules = {},
		_watermarks = {},
		_keybinds = {},
		_connectionsByName = {},
		_destroyed = false,
		_popup = nil,
		_draggingWindow = false,
		_cursorRestoreState = nil,
		_cursorStepName = "BacktrackUI_MouseUnlock_" .. tostring(cursorBindingCounter),
		_cursorRenderBound = false,
		_menuVisible = true,
		_visibilitySnapshot = nil,
		_nextDisplayOrder = (options.displayOrder or 100) + 1,
		_options = options,
	}, BacktrackUI)

	self.Gui = create("ScreenGui", {
		Name = options.name or "BacktrackUI",
		ResetOnSpawn = options.resetOnSpawn == true,
		IgnoreGuiInset = options.ignoreGuiInset ~= false,
		DisplayOrder = options.displayOrder or 100,
		ZIndexBehavior = options.zIndexBehavior or Enum.ZIndexBehavior.Sibling,
	}, parent)
	GuiThemes[self.Gui] = self.Theme

	local width = options.width or 604
	local height = options.height or 631
	local initialSize = options.size
	if typeof(initialSize) == "UDim2" then
		width = initialSize.X.Offset
		height = initialSize.Y.Offset
	end

	self.Outer = create("Frame", {
		Name = options.windowObjectName or "WindowOutline",
		AnchorPoint = options.anchorPoint or Vector2.new(0.5, 0.5),
		Position = options.position or UDim2.fromScale(0.5, 0.5),
		Size = typeof(initialSize) == "UDim2" and initialSize or UDim2.fromOffset(width, height),
		BackgroundColor3 = options.outlineColor or self.Theme.outline,
		BackgroundTransparency = options.outlineTransparency or 0,
		BorderSizePixel = options.borderSizePixel or 0,
		ClipsDescendants = options.clipsDescendants == true,
	}, self.Gui)
	local glowImage = self.Images.glow4 or self.Images.glow
	if glowImage then
		self.Glow = create("ImageLabel", {
			Name = "WindowGlow",
			Position = UDim2.fromOffset(-20, -20),
			Size = UDim2.new(1, 40, 1, 40),
			BackgroundTransparency = 1,
			Image = glowImage,
			ImageColor3 = self.Theme.glow,
			ImageTransparency = 0.8,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(21, 21, 79, 79),
			ZIndex = 0,
		}, self.Outer)
	end
	self.AccentFrame = create("Frame", {
		Name = "PinkInline",
		Position = options.accentFramePosition or UDim2.fromOffset(1, 1),
		Size = options.accentFrameSize or UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = options.accentColor or self.Theme.accent,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, self.Outer)

	self.Body = create("Frame", {
		Name = "WindowBody",
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = self.Theme.contrastTop,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, self.AccentFrame)
	gradient(self.Body, self.Theme.contrastTop, self.Theme.contrastBottom)

	self.Header = create("Frame", {
		Name = options.headerName or "Header",
		Position = options.headerPosition or UDim2.new(),
		Size = options.headerSize or UDim2.new(1, 0, 0, options.headerHeight or 18),
		BackgroundColor3 = options.headerColor or self.Theme.background,
		BackgroundTransparency = options.headerTransparency ~= nil and options.headerTransparency or 1,
		BorderSizePixel = 0,
		Active = true,
	}, self.Body)
	local headerTitle = label(self.Header, options.title or "Backtrack UI", self.Theme, {
		name = options.titleObjectName or "Title",
		position = options.titlePosition or UDim2.fromOffset(2, 4),
		size = options.titleSize or UDim2.new(1, -28, 0, 14),
		textSize = options.titleTextSize or 12,
		color = options.titleColor or self.Theme.accent,
		font = options.titleFont,
		align = options.titleAlign,
	})
	self.TitleLabel = headerTitle
	create("UIStroke", { LineJoinMode = Enum.LineJoinMode.Miter }, headerTitle)
	self.CloseButton = create("TextButton", {
		Name = options.closeButtonName or "Close",
		AnchorPoint = options.closeButtonAnchorPoint or Vector2.new(1, 0),
		Position = options.closeButtonPosition or UDim2.new(1, -7, 0, 5),
		Size = options.closeButtonSize or UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = options.closeButtonFont or Enum.Font.Legacy,
		Text = options.closeText or "X",
		TextSize = options.closeButtonTextSize or 12,
		TextXAlignment = options.closeButtonAlign or Enum.TextXAlignment.Right,
		TextColor3 = options.closeButtonColor or self.Theme.text,
		ZIndex = 100,
	}, self.Outer)
	create("UIStroke", {}, self.CloseButton)
	self.CloseButton.Activated:Connect(function()
		self.Gui.Enabled = false
		self:_syncCursor()
	end)

	self.PageOutline = create("Frame", {
		Name = "SectionOutline",
		Position = UDim2.fromOffset(options.pageOutlineX or 0, options.pageOutlineY or options.headerHeight or 18),
		Size = UDim2.new(1, options.pageOutlineWidthOffset or 0, 1, options.pageOutlineHeightOffset or -(options.headerHeight or 18)),
		BackgroundColor3 = self.Theme.inline,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, self.Body)
	self.PageInline = create("Frame", {
		Name = "SectionInline",
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = self.Theme.outline,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, self.PageOutline)
	local tabBarHeight = options.tabBarHeight or (typeof(options.tabBarSize) == "UDim2" and options.tabBarSize.Y.Offset) or 22
	self.TabBar = create("Frame", {
		Name = "Tabs",
		Position = options.tabBarPosition or UDim2.new(),
		Size = options.tabBarSize or UDim2.new(1, 0, 0, tabBarHeight),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, nil)
	self.Pages = create("Frame", {
		Name = "ContentHolder",
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = self.Theme.contrastTop,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, self.PageInline)
	gradient(self.Pages, self.Theme.contrastTop, self.Theme.contrastBottom)
	self.TabBar.Parent = self.Pages
	self.TabLayout = create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalFlex = options.tabBarFlex or Enum.UIFlexAlignment.Fill,
		SortOrder = options.tabSortOrder or Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, options.tabSpacing or 2),
	}, self.TabBar)
	local tabBarPadding = options.tabBarPadding or {}
	create("UIPadding", {
		PaddingTop = UDim.new(0, tabBarPadding.top or 0),
		PaddingBottom = UDim.new(0, tabBarPadding.bottom or 0),
		PaddingLeft = UDim.new(0, tabBarPadding.left or 0),
		PaddingRight = UDim.new(0, tabBarPadding.right or 0),
	}, self.TabBar)

	self.PageHost = create("Frame", {
		Name = "SectionHolder",
		Position = UDim2.new(0, options.pageHostX or -1, 0, options.pageHostY or tabBarHeight - 3),
		Size = UDim2.new(1, options.pageHostWidthOffset or 0, 1, options.pageHostHeightOffset or -tabBarHeight),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, self.Pages)
	local pageOutline = create("Frame", {
		Name = "Outline",
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, 0, 1, 2),
		BackgroundColor3 = self.Theme.outline,
		BorderSizePixel = 0,
	}, self.PageHost)
	local pageInline = create("Frame", {
		Name = "Inline",
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = self.Theme.inline,
		BorderSizePixel = 0,
	}, pageOutline)
	self.TabPages = create("Frame", {
		Name = "Pages",
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = self.Theme.contrastTop,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, pageInline)
	gradient(self.TabPages, self.Theme.contrastTop, self.Theme.contrastBottom)
	makeResizable(self, self.Outer)

	connect(self, self.Outer:GetPropertyChangedSignal("Visible"), function()
		self:_syncCursor()
	end)
	connect(self, self.Gui:GetPropertyChangedSignal("Enabled"), function()
		if not self.Gui.Enabled then self:_closePopup() end
		self:_syncCursor()
	end)
	self:_syncCursor()
	self._makeDrag(self)
	self._installInput(self)
	return self
end

BacktrackUI.Create = BacktrackUI.new

function BacktrackUI:_makeDrag()
	local startPosition
	local startInput
	connect(self, self.Header.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self._draggingWindow = true
			self._nextDisplayOrder = self._nextDisplayOrder + 1
			self.Gui.DisplayOrder = self._nextDisplayOrder
			startPosition = self.Outer.Position
			startInput = input.Position
		end
	end)
	connect(self, UserInputService.InputChanged, function(input)
		if self._draggingWindow and startInput and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - startInput
			self.Outer.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
		end
	end)
	connect(self, UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self._draggingWindow = false
		end
	end)
end

function BacktrackUI:_installInput()
	connect(self, UserInputService.InputBegan, function(input, processed)
		if self._destroyed then
			return
		end
		for _, bind in ipairs(self._keybinds) do
			if bind._capturing then
				local key = input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode or input.UserInputType
				bind._capturing = false
				bind:Set({ key = key, mode = bind.mode })
				return
			end
		end

		local toggleKeyPressed = self._options.toggleKey and inputMatches(input, self._options.toggleKey)
		local focusOk, focusedTextBox = pcall(function() return UserInputService:GetFocusedTextBox() end)
		if toggleKeyPressed and (not focusOk or not focusedTextBox) then
			self:Toggle()
		end
		if processed then
			return
		end
		for _, bind in ipairs(self._keybinds) do
			if bind.key and inputMatches(input, bind.key) then
				if bind.mode == "Toggle" then
					bind:SetActive(not bind.active)
				elseif bind.mode == "Hold" then
					bind:SetActive(true)
				elseif bind.mode == "Always" then
					bind:SetActive(true)
				end
			end
		end
	end)
	connect(self, UserInputService.InputEnded, function(input)
		for _, bind in ipairs(self._keybinds) do
			if bind.key and bind.mode == "Hold" and inputMatches(input, bind.key) then
				bind:SetActive(false)
			end
		end
	end)
end

function BacktrackUI:_openPopup(anchor, width, height, builder)
	self:_closePopup()
	local popupGui = anchor:FindFirstAncestorOfClass("ScreenGui") or self.Gui
	local catcher = create("TextButton", {
		Name = "PopupCatcher",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 80,
	}, popupGui)
	catcher.MouseButton1Click:Connect(function()
		self:_closePopup()
	end)

	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1024, 768)
	local anchorPosition = anchor.AbsolutePosition
	local anchorSize = anchor.AbsoluteSize
	local x = math.clamp(anchorPosition.X, 6, math.max(6, viewport.X - width - 6))
	local y = anchorPosition.Y + anchorSize.Y + 4
	if y + height > viewport.Y - 6 then
		y = math.max(6, anchorPosition.Y - height - 4)
	end
	local frame = create("Frame", {
		Name = "Popup",
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = self.Theme.surface,
		BorderSizePixel = 0,
		ZIndex = 90,
		ClipsDescendants = true,
	}, popupGui)
	corner(frame, 3)
	stroke(frame, self.Theme.border, 1)
	self._popup = { catcher = catcher, frame = frame }
	if builder then
		builder(frame)
	end
	return frame
end

function BacktrackUI:_closePopup()
	if self._popup then
		self._popup.catcher:Destroy()
		if self._popup.preserve then
			self._popup.frame.Visible = false
		else
			self._popup.frame:Destroy()
		end
		if self._popup.onClose then self._popup.onClose() end
		self._popup = nil
	end
end

function BacktrackUI:_registerControl(control, options, initial, setValue)
	self._controlIndex = (self._controlIndex or 0) + 1
	control.Name = options.name or "Control"
	control.Flag = options.flag or normalizeFlag(control.Name, self._controlIndex)
	control.Callback = options.callback
	control.Value = initial
	control._window = self
	control._row = control._row
	control._setValue = setValue
	control.Set = function(target, value, silent)
		return target._setValue(value, silent)
	end
	control.Get = function(target)
		return target.Value
	end
	control.SetVisible = function(target, visible)
		if target._row then
			target._row.Visible = visible ~= false
		end
	end
	control.Keybind = function(target, bindOptions) return target._section:_keybind(bindOptions, target._right, target) end
	control.Colorpicker = function(target, pickerOptions) return target._section:_colorpicker(pickerOptions, target._right, target) end
	control.Configuration = function(target, configOptions, builder) return target._section:Configuration(configOptions, builder, target) end
	control.keybind = control.Keybind
	control.colorpicker = control.Colorpicker
	control.configuration = control.Configuration
	self._flags[control.Flag] = control
	self._values[control.Flag] = copyValue(initial)
	table.insert(self._controls, control)
	if options.tooltip and control._row then self:AddTooltip(control._row, options.tooltip) end
	return control
end

function BacktrackUI:_setVisible(visible)
	visible = visible ~= false
	if visible then
		local snapshot = self._visibilitySnapshot
		self._menuVisible = true
		self.Gui.Enabled = snapshot == nil or snapshot.main == true
		self.Outer.Visible = true
		for _, panel in ipairs(self._panels) do
			panel.Gui.Enabled = snapshot ~= nil and snapshot.panels[panel] == true
		end
		self._visibilitySnapshot = nil
		if self.Dock then self.Dock:SetVisible(true) end
	else
		if not self._menuVisible then return end
		self:_closePopup()
		local snapshot = { main = self.Gui.Enabled, panels = {} }
		for _, panel in ipairs(self._panels) do
			snapshot.panels[panel] = panel.Gui.Enabled
		end
		self._visibilitySnapshot = snapshot
		self._menuVisible = false
		self.Gui.Enabled = false
		for _, panel in ipairs(self._panels) do panel.Gui.Enabled = false end
		if self.Dock then self.Dock:SetVisible(false) end
	end
	self:_syncCursor()
end

function BacktrackUI:_restoreCursor()
	if self._cursorRenderBound then
		pcall(function() RunService:UnbindFromRenderStep(self._cursorStepName) end)
		self._cursorRenderBound = false
	end
	if self.Pointer then self.Pointer.Visible = false end
	local previous = self._cursorRestoreState
	if not previous then return end
	self._cursorRestoreState = nil
	pcall(function() UserInputService.MouseBehavior = previous.mouseBehavior end)
	pcall(function() UserInputService.MouseIconEnabled = previous.mouseIconEnabled end)
end

function BacktrackUI:_hasOpenWindow()
	if not self._menuVisible then return false end
	if self.Gui and self.Gui.Enabled and self.Outer and self.Outer.Visible then return true end
	for _, panel in ipairs(self._panels) do
		if panel.Gui and panel.Gui.Enabled then return true end
	end
	if self.Dock and self.Dock.Frame and self.Dock.Frame.Parent and self.Dock.Frame.Visible then return true end
	return false
end

function BacktrackUI:_refreshPointer()
	local visible = self._pointerEnabled == true and self.Pointer ~= nil and self.Pointer.Image ~= "" and self:_hasOpenWindow()
	if self.Pointer then
		self.Pointer.Visible = visible
		if visible then
			local position = UserInputService:GetMouseLocation()
			self.Pointer.Position = UDim2.fromOffset(position.X, position.Y)
		end
	end
	return visible
end

function BacktrackUI:_syncCursor()
	local isOpen = self:_hasOpenWindow()
	local pointerVisible = self:_refreshPointer()
	if not isOpen then
		self:_restoreCursor()
		return
	end

	if not self._cursorRestoreState then
		local behaviorOk, mouseBehavior = pcall(function() return UserInputService.MouseBehavior end)
		local iconOk, mouseIconEnabled = pcall(function() return UserInputService.MouseIconEnabled end)
		if not behaviorOk or not iconOk then return end
		self._cursorRestoreState = {
			mouseBehavior = mouseBehavior,
			mouseIconEnabled = mouseIconEnabled,
		}
	end

	pcall(function() UserInputService.MouseBehavior = Enum.MouseBehavior.Default end)
	pcall(function() UserInputService.MouseIconEnabled = not pointerVisible end)
	if not self._cursorRenderBound then
		local bound = pcall(function()
			RunService:BindToRenderStep(self._cursorStepName, Enum.RenderPriority.Last.Value + 1, function()
				if self._destroyed then return end
				local hasOpenWindow = self:_hasOpenWindow()
				if not hasOpenWindow then self:_refreshPointer(); return end
				local activePointer = self:_refreshPointer()
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
				UserInputService.MouseIconEnabled = not activePointer
			end)
		end)
		self._cursorRenderBound = bound
	end
end

function BacktrackUI:SetTheme(overrides)
	local nextTheme = mergeTheme(overrides, self.Theme)
	for key, value in pairs(nextTheme) do self.Theme[key] = value end
	local themeGuis = { self.Gui }
	if self.OverlayGui then table.insert(themeGuis, self.OverlayGui) end
	for _, watermark in ipairs(self._watermarks) do
		if watermark.Gui and watermark.Gui.Parent then table.insert(themeGuis, watermark.Gui) end
	end
	for _, panel in ipairs(self._panels) do
		if panel.Gui and panel.Gui.Parent then table.insert(themeGuis, panel.Gui) end
	end
	for _, gui in ipairs(themeGuis) do GuiThemes[gui] = self.Theme end
	if self._destroyed then return self.Theme end
	if not self._themeRefreshConnection then
		self._themeRefreshConnection = RunService.RenderStepped:Connect(function()
			local connection = self._themeRefreshConnection
			self._themeRefreshConnection = nil
			if connection then connection:Disconnect() end
			if not self._destroyed then applyThemeChanges(self) end
		end)
	end
	return self.Theme
end

function BacktrackUI:SetVisible(visible)
	self:_setVisible(visible)
end

function BacktrackUI:SetTitle(text)
	self.TitleLabel.Text = tostring(text or "")
	return self.TitleLabel.Text
end

function BacktrackUI:SetPosition(position)
	self.Outer.Position = position
	return position
end

function BacktrackUI:SetSize(size)
	self.Outer.Size = size
	return size
end

function BacktrackUI:Toggle()
	local visible = not self._menuVisible
	self:_setVisible(visible)
	return visible
end

function BacktrackUI:SelectTab(tabOrName)
	for _, tab in ipairs(self._tabs) do
		if tab._visible and (tab == tabOrName or tab.Name == tabOrName) then
			tab:SetActive(true)
			return tab
		end
	end
	return nil
end

function BacktrackUI:GetTabs()
	local tabs = {}
	for index, tab in ipairs(self._tabs) do tabs[index] = tab end
	return tabs
end

function BacktrackUI:RemoveTab(tabOrName)
	for _, tab in ipairs(self._tabs) do
		if tab == tabOrName or tab.Button == tabOrName or tab.Name == tabOrName then
			tab:Destroy()
			return true
		end
	end
	return false
end

function BacktrackUI:ClearTabs()
	while #self._tabs > 0 do self._tabs[#self._tabs]:Destroy() end
end

function BacktrackUI:GetValues()
	local values = {}
	for flag, control in pairs(self._flags) do
		local value
		if control.Get then value = control:Get() else value = control.Value end
		values[flag] = copyValue(value)
	end
	return values
end

function BacktrackUI:SetValues(values, silent)
	for flag, value in pairs(values or {}) do
		local control = self._flags[flag]
		if control then
			control:Set(value, silent)
		end
	end
end

function BacktrackUI:Notify(message, duration, kind)
	local theme = self.Theme
	self._notificationIndex = (self._notificationIndex or 0) + 1
	local holder = self._notificationHolder
	if not holder then
		holder = create("Frame", {
			Name = "Notifications",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -14, 1, -14),
			Size = UDim2.fromOffset(300, 240),
			BackgroundTransparency = 1,
			ZIndex = 30,
		}, self.Gui)
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}, holder)
		self._notificationHolder = holder
	end
	local color = kind == "error" and theme.negative or (kind == "success" and theme.positive or theme.accent)
	local toast = create("Frame", {
		Name = "Notification",
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = theme.surface,
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		ZIndex = 31,
		LayoutOrder = self._notificationIndex,
	}, holder)
	corner(toast, 3)
	stroke(toast, theme.border, 1)
	create("Frame", {
		Size = UDim2.new(0, 3, 1, -8),
		Position = UDim2.fromOffset(4, 4),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 32,
	}, toast)
	label(toast, message, theme, {
		position = UDim2.fromOffset(14, 3),
		size = UDim2.new(1, -22, 1, -6),
		wrapped = true,
		textSize = 11,
		zIndex = 32,
	})
	TweenService:Create(toast, TweenInfo.new(0.16), { BackgroundTransparency = 0 }):Play()
	task.delay(duration or 3, function()
		if toast.Parent then
			local tween = TweenService:Create(toast, TweenInfo.new(0.18), { BackgroundTransparency = 1 })
			tween:Play()
			tween.Completed:Wait()
			if toast.Parent then
				toast:Destroy()
			end
		end
	end)
	return toast
end

function BacktrackUI:AddTooltip(target, text)
	local tooltip
	local moveConnection
	local function close()
		if moveConnection then
			moveConnection:Disconnect()
			for index, connection in ipairs(self._connections) do
				if connection == moveConnection then table.remove(self._connections, index); break end
			end
			moveConnection = nil
		end
		if tooltip then
			tooltip:Destroy()
			tooltip = nil
		end
	end
	connect(self, target.MouseEnter, function()
		close()
		local position = UserInputService:GetMouseLocation()
		local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1024, 768)
		local x = math.clamp(position.X + 12, 6, math.max(6, viewport.X - 230))
		local y = math.clamp(position.Y + 16, 6, math.max(6, viewport.Y - 64))
		tooltip = create("Frame", {
			Name = "Tooltip",
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(224, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = self.Theme.surface,
			BorderSizePixel = 0,
			ZIndex = 75,
		}, target:FindFirstAncestorOfClass("ScreenGui") or self.Gui)
		corner(tooltip, 3)
		stroke(tooltip, self.Theme.border, 1)
		local tipText = label(tooltip, text, self.Theme, {
			position = UDim2.fromOffset(7, 5),
			size = UDim2.new(1, -14, 0, 0),
			textSize = 10,
			color = self.Theme.text,
			wrapped = true,
			automaticSize = Enum.AutomaticSize.Y,
			zIndex = 76,
		})
		create("UIPadding", { PaddingBottom = UDim.new(0, 5) }, tooltip)
		moveConnection = UserInputService.InputChanged:Connect(function(input)
			if tooltip and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local cursor = UserInputService:GetMouseLocation()
				local nextX = math.clamp(cursor.X + 12, 6, math.max(6, viewport.X - 230))
				local nextY = math.clamp(cursor.Y + 16, 6, math.max(6, viewport.Y - math.max(48, tipText.AbsoluteSize.Y + 12)))
				tooltip.Position = UDim2.fromOffset(nextX, nextY)
			end
		end)
		table.insert(self._connections, moveConnection)
	end)
	connect(self, target.MouseLeave, close)
	return close
end

function BacktrackUI:_getOverlayGui()
	if self.OverlayGui and self.OverlayGui.Parent then return self.OverlayGui end
	self.OverlayGui = create("ScreenGui", {
		Name = self.Gui.Name .. "_Overlay",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = self._options.overlayDisplayOrder or 9999999,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, self.Gui.Parent)
	GuiThemes[self.OverlayGui] = self.Theme
	return self.OverlayGui
end

function BacktrackUI:CreatePointer(options)
	options = options or {}
	if self.Pointer and self.Pointer.Parent then return self.PointerHandle end
	local position = UserInputService:GetMouseLocation()
	self._pointerEnabled = options.enabled ~= false
	self.Pointer = create("ImageLabel", {
		Name = "BacktrackPointer",
		Image = options.image or self.Images.pointer or "",
		ImageColor3 = self.Theme.accent,
		ResampleMode = Enum.ResamplerMode.Pixelated,
		Position = UDim2.fromOffset(position.X, position.Y),
		Size = options.size or UDim2.fromOffset(14, 14),
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 999999999,
	}, self:_getOverlayGui())
	connect(self, UserInputService.InputChanged, function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then self:_refreshPointer() end
	end)
	local handle = { Object = self.Pointer }
	function handle:SetEnabled(enabled) self._window:SetPointerEnabled(enabled) end
	function handle:Destroy()
		self._window:SetPointerEnabled(false)
		if self.Object and self.Object.Parent then self.Object:Destroy() end
		self._window.Pointer = nil
	end
	handle._window = self
	self.PointerHandle = handle
	self:_syncCursor()
	return handle
end

function BacktrackUI:SetPointerEnabled(enabled)
	self._pointerEnabled = enabled ~= false
	self:_syncCursor()
	return self._pointerEnabled
end

function BacktrackUI:CreateKeybindList(options)
	options = options or {}
	local frame = create("Frame", {
		Name = "KeybindList",
		Position = options.position or UDim2.fromOffset(50, 269),
		Size = options.size or UDim2.fromOffset(200, 25),
		BackgroundColor3 = self.Theme.outline,
		BorderSizePixel = 0,
		Visible = options.visible == true,
		Active = true,
	}, self:_getOverlayGui())
	local glowImage = self.Images.glow4 or self.Images.glow
	if glowImage then
		create("ImageLabel", {
			Name = "KeybindListGlow",
			Position = UDim2.fromOffset(-20, -20),
			Size = UDim2.new(1, 40, 1, 40),
			BackgroundTransparency = 1,
			Image = glowImage,
			ImageColor3 = self.Theme.glow,
			ImageTransparency = 0.8,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(21, 21, 79, 79),
			ZIndex = 0,
		}, frame)
	end
	local inline = create("Frame", {
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = self.Theme.inline,
		BorderSizePixel = 0,
	}, frame)
	local outline = create("Frame", {
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = self.Theme.outline,
		BorderSizePixel = 0,
	}, inline)
	local surface = create("Frame", {
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = self.Theme.contrastTop,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, outline)
	gradient(surface, self.Theme.contrastTop, self.Theme.contrastBottom)
	create("Frame", {
		Name = "AccentBar",
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = self.Theme.accent,
		BorderSizePixel = 0,
	}, surface)
	local title = label(surface, "Keybinds", self.Theme, {
		name = "KeybindsTitle",
		size = UDim2.new(1, 0, 1, 0),
		textSize = 12,
		align = Enum.TextXAlignment.Center,
		color = self.Theme.text,
		truncate = true,
	})
	create("UIStroke", { LineJoinMode = Enum.LineJoinMode.Miter }, title)
	local listOuter = create("Frame", {
		Name = "KeybindRowsOutline",
		Position = UDim2.new(0, -2, 1, 1),
		Size = UDim2.new(1, 4, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = self.Theme.outline,
		BorderSizePixel = 0,
	}, surface)
	local listInline = create("Frame", {
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = self.Theme.inline,
		BorderSizePixel = 0,
	}, listOuter)
	local listSurface = create("Frame", {
		Name = "KeybindRows",
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = self.Theme.contrastTop,
		BorderSizePixel = 0,
	}, listInline)
	gradient(listSurface, self.Theme.contrastTop, self.Theme.contrastBottom)
	create("UIListLayout", { Padding = UDim.new(0, -1), SortOrder = Enum.SortOrder.LayoutOrder }, listSurface)
	create("UIPadding", { PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 5) }, listSurface)
	local dragStart, positionStart
	connect(self, frame.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragStart, positionStart = input.Position, frame.Position
		end
	end)
	connect(self, UserInputService.InputChanged, function(input)
		if dragStart and positionStart and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(positionStart.X.Scale, positionStart.X.Offset + delta.X, positionStart.Y.Scale, positionStart.Y.Offset + delta.Y)
		end
	end)
	connect(self, UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragStart = nil end
	end)
	makeResizable(self, frame)
	local handle = { Object = frame, Rows = listSurface, _window = self }
	function handle:SetVisible(visible) frame.Visible = visible ~= false end
	function handle:Refresh()
		for _, child in ipairs(listSurface:GetChildren()) do
			if child:IsA("GuiObject") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then child:Destroy() end
		end
		for _, bind in ipairs(self._window._keybinds) do
			if bind.Name ~= "UI Bind" and bind.key and bind.active then
				local row = create("Frame", {
					Name = "KeybindRow",
					Size = UDim2.new(1, -5, 0, 16),
					BackgroundTransparency = 1,
					LayoutOrder = #listSurface:GetChildren(),
				}, listSurface)
				label(row, bind.Name, self._window.Theme, { size = UDim2.new(1, -55, 1, 0), textSize = 12 })
				label(row, keyName(bind.key), self._window.Theme, {
					position = UDim2.new(1, -50, 0, 0),
					size = UDim2.fromOffset(50, 16),
					textSize = 12,
					align = Enum.TextXAlignment.Right,
				})
			end
		end
	end
	function handle:Destroy()
		if self._window._keybindList == self then self._window._keybindList = nil end
		if frame.Parent then frame:Destroy() end
	end
	self._keybindList = handle
	handle:Refresh()
	return handle
end

function BacktrackUI:CreatePanel(title, options)
	options = options or {}
	self._nextDisplayOrder = self._nextDisplayOrder + 1
	local safeName = tostring(options.name or title or "Panel"):gsub("[^%w_%-]", "_")
	local panelGui = create("ScreenGui", {
		Name = self.Gui.Name .. "_" .. safeName .. "_Gui",
		Enabled = options.visible ~= false,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = options.displayOrder or self._nextDisplayOrder,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, options.parent or self.Gui.Parent)
	GuiThemes[panelGui] = self.Theme
	local panel = { _window = self, _rows = {}, Name = title or "Panel", Image = options.image, Gui = panelGui }
	local frame = create("Frame", {
		Name = options.name or "UtilityPanel",
		Position = options.position or UDim2.fromOffset(24, 100),
		Size = options.size or UDim2.fromOffset(260, 220),
		BackgroundColor3 = self.Theme.outline,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Active = true,
	}, panelGui)
	connect(self, panelGui:GetPropertyChangedSignal("Enabled"), function()
		if not panelGui.Enabled then self:_closePopup() end
		self:_syncCursor()
	end)
	local glowImage = self.Images.glow4 or self.Images.glow
	if glowImage then
		create("ImageLabel", {
			Name = "PanelGlow",
			Position = UDim2.fromOffset(-20, -20),
			Size = UDim2.new(1, 40, 1, 40),
			BackgroundTransparency = 1,
			Image = glowImage,
			ImageColor3 = self.Theme.glow,
			ImageTransparency = 0.8,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(21, 21, 79, 79),
			ZIndex = 0,
		}, frame)
	end
	panel.Frame = frame
	local accentFrame = create("Frame", {
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = self.Theme.accent,
		BorderSizePixel = 0,
	}, frame)
	local inner = create("Frame", {
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = self.Theme.contrastTop,
		BorderSizePixel = 0,
	}, accentFrame)
	gradient(inner, self.Theme.contrastTop, self.Theme.contrastBottom)
	local outlineContent = create("Frame", {
		Position = UDim2.new(0, 0, 0, 18),
		Size = UDim2.new(1, 0, 1, -18),
		BackgroundColor3 = self.Theme.inline,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, inner)
	local innerOutline = create("Frame", {
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = self.Theme.outline,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, outlineContent)
	local contentFrame = create("Frame", {
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = self.Theme.contrastTop,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, innerOutline)
	gradient(contentFrame, self.Theme.contrastTop, self.Theme.contrastBottom)
	local bar = create("Frame", {
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = true,
	}, inner)
	local panelTitle = label(bar, title or "Panel", self.Theme, {
	position = UDim2.fromOffset(2, 4),
	size = UDim2.new(1, -23, 0, 14),
	textSize = 12,
	color = self.Theme.accent,
})
	create("UIStroke", { LineJoinMode = Enum.LineJoinMode.Miter }, panelTitle)
	local close = create("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -7, 0, 5),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Enum.Font.Legacy,
		Text = "X",
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = self.Theme.text,
		ZIndex = 100,
	}, frame)
	create("UIStroke", {}, close)
	close.Activated:Connect(function() panelGui.Enabled = false end)
	local content = create("ScrollingFrame", {
		Name = "PanelContent",
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.new(1, -10, 1, -10),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	ScrollBarThickness = 0,
		ScrollBarImageColor3 = self.Theme.accent,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, contentFrame)
	panel.Content = content
	create("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, content)
	local start, inputStart
	connect(self, bar.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			panel:BringToFront()
			start, inputStart = frame.Position, input.Position
		end
	end)
	connect(self, UserInputService.InputChanged, function(input)
		if start and inputStart and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - inputStart
			frame.Position = UDim2.new(start.X.Scale, start.X.Offset + delta.X, start.Y.Scale, start.Y.Offset + delta.Y)
		end
	end)
	connect(self, UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			start = nil
		end
	end)
	connect(self, frame.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			panel:BringToFront()
		end
	end)
	makeResizable(self, frame)

	function panel:AddLabel(text)
		local row = label(content, text, self._window.Theme, { size = UDim2.new(1, -8, 0, 20), position = UDim2.fromOffset(4, 0), wrapped = true })
		table.insert(self._rows, row)
		return row
	end
	function panel:AddSection(name)
		local section = createSection(self._window, content, name or "Section", "PanelSection_" .. tostring(#self._rows + 1), math.max(120, self.Frame.Size.Y.Offset - 36))
		section.Gui = panelGui
		section.Frame.Size = UDim2.new(1, -8, 0, math.max(120, self.Frame.Size.Y.Offset - 36))
		section.Frame.LayoutOrder = #self._rows + 1
		table.insert(self._rows, section.Frame)
		return section
	end
	function panel:AddColumn()
		local frame = create("Frame", {
			Name = "Column",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
		}, content)
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			VerticalFlex = Enum.UIFlexAlignment.Fill,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, frame)
		return setmetatable({ _window = self._window, _gui = panelGui, Frame = frame, _sectionCount = 0 }, Column)
	end
	function panel:AddButton(text, callback)
		local row = button(content, text, self._window.Theme, { size = UDim2.new(1, -8, 0, 25), position = UDim2.fromOffset(4, 0) })
		row.Activated:Connect(function() invoke(callback) end)
		table.insert(self._rows, row)
		return row
	end
	function panel:AddList(items)
		local listFrame = create("Frame", { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, content)
		create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, listFrame)
		local list = { Frame = listFrame }
		function list:SetItems(nextItems)
			for _, child in ipairs(listFrame:GetChildren()) do
				if child:IsA("TextLabel") then child:Destroy() end
			end
			for _, item in ipairs(nextItems or {}) do
				label(listFrame, tostring(item), list._window.Theme, { size = UDim2.new(1, 0, 0, 18), color = list._window.Theme.muted })
			end
		end
		list._window = self._window
		list:SetItems(items)
		table.insert(self._rows, listFrame)
		return list
	end
	function panel:SetVisible(visible)
		panelGui.Enabled = visible ~= false
		if panelGui.Enabled then self:BringToFront() end
	end
	function panel:Toggle()
		panelGui.Enabled = not panelGui.Enabled
		if panelGui.Enabled then self:BringToFront() end
		return panelGui.Enabled
	end
	function panel:BringToFront()
		self._window._nextDisplayOrder = self._window._nextDisplayOrder + 1
		panelGui.DisplayOrder = self._window._nextDisplayOrder
	end
	function panel:Destroy()
		if panelGui.Parent then panelGui:Destroy() end
		for index, item in ipairs(self._window._panels) do
			if item == self then table.remove(self._window._panels, index) break end
		end
		if self._window.Dock then self._window.Dock:Refresh() end
	end
	table.insert(self._panels, panel)
	if self.Dock then self.Dock:Refresh() end
	return panel
end

function BacktrackUI:CreateLuaModuleManager(options)
	options = options or {}
	local existing = self._luaModuleManager
	if existing and existing.Panel and existing.Panel.Gui and existing.Panel.Gui.Parent then
		return existing
	end

	local panel = self:CreatePanel(options.title or "Lua Modules", {
		name = options.name or "LuaModules",
		image = options.image or "lua",
		position = options.position or UDim2.fromOffset(40, 110),
		size = options.size or UDim2.fromOffset(390, 420),
		visible = options.visible == true,
	})
	local manager = { _window = self, Panel = panel, Modules = self._luaModules, _nextModuleId = 0 }
	self._luaModuleManager = manager
	self.LuaModules = manager

	local content = panel.Content
	local form = create("Frame", {
		Name = "ModuleForm",
		Size = UDim2.new(1, -8, 0, 238),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
	}, content)
	label(form, "Add a Lua module", self.Theme, { size = UDim2.new(1, -8, 0, 17), position = UDim2.fromOffset(4, 0), color = self.Theme.accent })
	label(form, "Module name", self.Theme, { size = UDim2.new(1, -8, 0, 14), position = UDim2.fromOffset(4, 19), color = self.Theme.muted, textSize = 11 })
	local nameInput = create("TextBox", {
		Name = "ModuleName",
		Position = UDim2.fromOffset(4, 34),
		Size = UDim2.new(1, -8, 0, 22),
		BackgroundColor3 = self.Theme.outline,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = Enum.Font.Legacy,
		PlaceholderText = "Example Module",
		PlaceholderColor3 = self.Theme.muted,
		Text = "",
		TextColor3 = self.Theme.text,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, form)
	stroke(nameInput, self.Theme.inline, 1)
	create("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }, nameInput)
	label(form, "Lua source", self.Theme, { size = UDim2.new(1, -8, 0, 14), position = UDim2.fromOffset(4, 59), color = self.Theme.muted, textSize = 11 })
	local sourceInput = create("TextBox", {
		Name = "ModuleSource",
		Position = UDim2.fromOffset(4, 75),
		Size = UDim2.new(1, -8, 0, 108),
		BackgroundColor3 = self.Theme.outline,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = Enum.Font.Code,
		MultiLine = true,
		PlaceholderText = 'local menu, manager, module = ...\nreturn {\n    Window = { iconText = "M" },\n    Build = function(panel, module, menu, manager) end,\n    Settings = { Enabled = { type = "toggle", default = true } },\n    OnEnable = function(module) end,\n    OnDisable = function(module) end,\n}',
		PlaceholderColor3 = self.Theme.muted,
		Text = "",
		TextColor3 = self.Theme.text,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = false,
	}, form)
	stroke(sourceInput, self.Theme.inline, 1)
	create("UIPadding", {
		PaddingLeft = UDim.new(0, 5),
		PaddingRight = UDim.new(0, 5),
		PaddingTop = UDim.new(0, 4),
	}, sourceInput)
	local status = label(form, "Modules are kept for this UI session.", self.Theme, {
		size = UDim2.new(1, -104, 0, 18),
		position = UDim2.fromOffset(4, 213),
		color = self.Theme.muted,
		textSize = 10,
		truncate = true,
	})
	local function setStatus(message, color)
		status.Text = tostring(message or "")
		status.TextColor3 = color or self.Theme.muted
	end
	local addButton = button(form, "Add Module", self.Theme, {
		position = UDim2.new(1, -94, 0, 210),
		size = UDim2.fromOffset(90, 24),
		textSize = 10,
		background = self.Theme.inline,
		border = self.Theme.accent,
	})

	local listFrame = create("Frame", {
		Name = "ModuleList",
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
	}, content)
	create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, listFrame)
	label(listFrame, "Your modules", self.Theme, { size = UDim2.new(1, -4, 0, 17), position = UDim2.fromOffset(2, 0), color = self.Theme.accent })
	local rows = create("Frame", {
		Name = "ModuleRows",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
	}, listFrame)
	create("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, rows)

	local function findModule(name)
		for _, module in ipairs(manager.Modules) do
			if module.Name == name then return module end
		end
		return nil
	end
	local function copySettings(value)
		local result = {}
		for key, item in pairs(value or {}) do result[key] = item end
		return result
	end
	local function getDefinitionMember(definition, ...)
		for index = 1, select("#", ...) do
			local key = select(index, ...)
			if definition[key] ~= nil then return definition[key] end
		end
		return nil
	end
	local function settingEntries(settings)
		local entries = {}
		for key, value in pairs(settings or {}) do
			if type(value) == "table" then
				local name = tostring(value.key or value.Key or value.name or value.Name or key)
				table.insert(entries, { Key = name, Options = value })
			else
				table.insert(entries, { Key = tostring(key), Options = { default = value } })
			end
		end
		table.sort(entries, function(left, right)
			local leftOrder = tonumber(left.Options.order or left.Options.Order) or math.huge
			local rightOrder = tonumber(right.Options.order or right.Options.Order) or math.huge
			if leftOrder == rightOrder then return left.Key < right.Key end
			return leftOrder < rightOrder
		end)
		return entries
	end
	local function defaultSettingValue(options, kind)
		local value = options.default
		if value == nil then value = options.Default end
		if value == nil then value = options.value end
		if value == nil then value = options.Value end
		if kind == "toggle" then return value == true end
		if kind == "slider" then return tonumber(value) or tonumber(options.min or options.minimum) or 0 end
		if kind == "dropdown" or kind == "multidropdown" then
			if value ~= nil then return value end
			local items = options.items or options.options or options.values or {}
			if kind == "multidropdown" then return {} end
			local first = items[1]
			return type(first) == "table" and (first.value or first.name or first[1]) or first
		end
		if kind == "textbox" then return tostring(value or "") end
		if kind == "color" or kind == "colorpicker" then
			if type(value) == "table" then
				return { color = value.color or value[1] or options.color or Color3.new(1, 1, 1), alpha = value.alpha or value[2] or options.alpha or 1 }
			end
			return { color = (typeof(value) == "Color3" and value) or options.color or Color3.new(1, 1, 1), alpha = options.alpha or 1 }
		end
		if kind == "keybind" then
			if type(value) == "table" then return value end
			return { key = value or options.key, mode = options.mode or "Toggle", active = options.active == true }
		end
		return value
	end
	local function normalizeModuleSettings(module)
		local definition = module.Definition or {}
		local settings = getDefinitionMember(definition, "Settings", "settings", "Options", "options") or module.StaticSettings or {}
		module._settingEntries = settingEntries(settings)
		module._settingsByName = {}
		for _, entry in ipairs(module._settingEntries) do
			local options = entry.Options
			local kind = tostring(options.type or options.Type or "toggle"):lower():gsub("[%s%-]", "_")
			local aliases = {
				checkbox = "toggle",
				input = "textbox",
				string = "textbox",
				text = "textbox",
				multiselect = "multidropdown",
				multi_dropdown = "multidropdown",
				color_picker = "colorpicker",
				bind = "keybind",
			}
			kind = aliases[kind] or kind
			entry.Type = kind
			module._settingsByName[entry.Key] = entry
			if module.Values[entry.Key] == nil then
				module.Values[entry.Key] = copyValue(defaultSettingValue(options, kind))
			elseif kind == "color" or kind == "colorpicker" then
				local value = module.Values[entry.Key]
				if typeof(value) == "Color3" then module.Values[entry.Key] = { color = value, alpha = options.alpha or 1 } end
			end
		end
	end
	local function callModuleCallback(callback, ...)
		if type(callback) ~= "function" then return true end
		local ok, result = pcall(callback, ...)
		if not ok then return false, tostring(result) end
		if result == false then return false, "Module callback returned false." end
		return true, result
	end
	local function contextFor(module)
		if module.Context then return module.Context end
		local context = {
			Manager = manager,
			Menu = manager._window,
			Module = module,
			Settings = module.Values,
			Enabled = module.Enabled == true,
		}
		function context:Get(name)
			return copyValue(module.Values[tostring(name)])
		end
		function context:Set(name, value, silent)
			name = tostring(name)
			module.Values[name] = copyValue(value)
			self.Settings = module.Values
			local entry = module._settingsByName and module._settingsByName[name]
			if entry and entry.Control and type(entry.Control.Set) == "function" then
				entry.Control:Set(copyValue(value), true)
			end
			if not silent then
				local definition = module.Definition or {}
				local settingCallback = entry and (entry.Options.onChanged or entry.Options.OnChanged or entry.Options.callback or entry.Options.Callback)
				local callback = settingCallback or getDefinitionMember(definition, "OnSettingChanged", "onSettingChanged")
				if type(settingCallback) == "function" then
					local ok, err = callModuleCallback(callback, copyValue(module.Values[name]), self, name)
					if not ok then setStatus(err, manager._window.Theme.negative) end
				elseif type(callback) == "function" then
					local ok, err = callModuleCallback(callback, name, copyValue(module.Values[name]), self)
					if not ok then setStatus(err, manager._window.Theme.negative) end
				end
			end
			return copyValue(module.Values[name])
		end
		function context:Notify(message, duration, kind)
			return manager._window:Notify(message, duration, kind)
		end
		function context:Enable()
			return manager:EnableModule(module.Name)
		end
		function context:Disable()
			return manager:DisableModule(module.Name)
		end
		function context:IsEnabled() return module.Enabled == true end
		function context:OpenSettings() return manager:OpenModule(module.Name) end
		function context:OpenWindow() return manager:OpenModule(module.Name) end
		module.Context = context
		return context
	end
	function manager:_BuildSettingsPanel(module)
		self:_DestroySettingsPanel(module)
		normalizeModuleSettings(module)
		local definition = module.Definition or {}
		local windowOptions = getDefinitionMember(definition, "Window", "window") or {}
		if type(windowOptions) ~= "table" then windowOptions = {} end
		local safeName = tostring(module.Name):gsub("[^%w_%-]", "_")
		local panelTitle = windowOptions.title or windowOptions.Title or windowOptions.name or windowOptions.Name or module.Name
		local panel = self._window:CreatePanel(panelTitle, {
			name = "Module_" .. safeName .. "_" .. tostring(module.Id),
			image = windowOptions.icon or windowOptions.Icon or windowOptions.image or windowOptions.Image,
			position = windowOptions.position or UDim2.fromOffset(options.settingsPositionX or 430, options.settingsPositionY or 110),
			size = windowOptions.size or options.settingsSize or UDim2.fromOffset(320, 410),
			visible = windowOptions.visible == true,
		})
		module.Panel = panel
		module.SettingsPanel = panel
		local context = contextFor(module)
		local build = getDefinitionMember(definition, "Build", "build", "CreateUI", "createUI")
		if type(build) == "function" then
			local ok, err = callModuleCallback(build, panel, context, self._window, self)
			if not ok then setStatus("Build " .. module.Name .. ": " .. err, self._window.Theme.negative) end
		end
		if #module._settingEntries > 0 then
			local section = panel:AddSection(windowOptions.settingsTitle or windowOptions.SettingsTitle or "Settings")
			for _, entry in ipairs(module._settingEntries) do
				local settingKey = entry.Key
				local descriptor = entry.Options
				local kind = entry.Type
				local value = module.Values[entry.Key]
				local controlOptions = copySettings(descriptor)
				controlOptions.name = descriptor.label or descriptor.Label or descriptor.title or descriptor.Title or entry.Key
				controlOptions.flag = "module_" .. tostring(module.Id) .. "_" .. entry.Key:gsub("[^%w_]", "_")
				controlOptions.callback = nil
				local function changed(nextValue, alpha)
					if kind == "color" or kind == "colorpicker" then
						context:Set(settingKey, { color = nextValue, alpha = alpha })
					else
						context:Set(settingKey, nextValue)
					end
				end
				if kind == "toggle" then
					controlOptions.default = value == true
					controlOptions.callback = function(nextValue) changed(nextValue) end
					entry.Control = section:Toggle(controlOptions)
				elseif kind == "slider" then
					controlOptions.default = value
					controlOptions.callback = function(nextValue) changed(nextValue) end
					entry.Control = section:Slider(controlOptions)
				elseif kind == "dropdown" or kind == "multidropdown" then
					controlOptions.items = descriptor.items or descriptor.options or descriptor.values or {}
					controlOptions.default = value
					controlOptions.multi = kind == "multidropdown" or descriptor.multi == true
					controlOptions.callback = function(nextValue) changed(nextValue) end
					entry.Control = section:Dropdown(controlOptions)
				elseif kind == "textbox" then
					controlOptions.default = value
					controlOptions.callback = function(nextValue) changed(nextValue) end
					entry.Control = section:Textbox(controlOptions)
				elseif kind == "color" or kind == "colorpicker" then
					controlOptions.color = value.color
					controlOptions.default = value.color
					controlOptions.alpha = value.alpha
					controlOptions.callback = function(color, alpha) changed(color, alpha) end
					entry.Control = section:Colorpicker(controlOptions)
				elseif kind == "keybind" then
					controlOptions.key = value.key
					controlOptions.mode = value.mode
					controlOptions.default = value.active
					controlOptions.callback = function(active, key, mode)
						context:Set(settingKey, { key = key, mode = mode, active = active })
					end
					entry.Control = section:Keybind(controlOptions)
				elseif kind == "button" or kind == "action" then
					local action = descriptor.onClick or descriptor.OnClick or descriptor.callback or descriptor.Callback
					entry.Control = section:Button({
						name = controlOptions.name,
						text = descriptor.text or descriptor.Text or controlOptions.name,
						callback = function()
							local ok, err = callModuleCallback(action, context, self._window, self)
							if not ok then setStatus(err, self._window.Theme.negative) end
						end,
					})
				elseif kind == "label" then
					section:Label({ text = descriptor.text or descriptor.default or controlOptions.name })
				else
					section:Label({ name = controlOptions.name, text = "Unsupported setting type: " .. kind, color = self._window.Theme.warning })
				end
			end
		end
		self:_RegisterDockItem(module)
		return panel
	end
	function manager:_RegisterDockItem(module, dock)
		dock = dock or self._window.Dock
		if module.DockItem and module.DockItem._dock == dock and not module.DockItem._destroyed then return module.DockItem end
		module.DockItem = nil
		if not dock or not module.Panel then return nil end
		local definition = module.Definition or {}
		local windowOptions = getDefinitionMember(definition, "Window", "window") or {}
		if type(windowOptions) ~= "table" then windowOptions = {} end
		local dockOptions = getDefinitionMember(windowOptions, "Dock", "dock", "DockOptions", "dockOptions")
		if dockOptions == nil then dockOptions = getDefinitionMember(definition, "Dock", "dock") end
		local autoDock = getDefinitionMember(windowOptions, "AutoDock", "autoDock")
		if type(dockOptions) == "boolean" then autoDock, dockOptions = dockOptions, {} end
		if type(dockOptions) ~= "table" then dockOptions = {} end
		if autoDock == false then return nil end
		local config = copySettings(dockOptions)
		config.name = config.name or windowOptions.dockName or windowOptions.DockName or module.Name
		config.icon = config.icon or windowOptions.icon or windowOptions.Icon or windowOptions.image or windowOptions.Image
			or getDefinitionMember(definition, "Icon", "icon", "Image", "image") or module.Icon
		config.iconText = config.iconText or windowOptions.iconText or windowOptions.IconText or string.upper(string.sub(module.Name, 1, 1))
		module.DockItem = dock:AddPanel(module.Panel, config)
		return module.DockItem
	end
	function manager:_AttachDock(dock)
		for _, module in ipairs(self.Modules) do
			if module.Panel then self:_RegisterDockItem(module, dock) end
		end
	end
	function manager:_DestroySettingsPanel(module)
		local modulePanel = module.Panel or module.SettingsPanel
		local prefix = "module_" .. tostring(module.Id) .. "_"
		local function belongsToPanel(control)
			local row = control and control._row
			if not modulePanel or not row then return false end
			local ok, isDescendant = pcall(function() return row:IsDescendantOf(modulePanel.Gui) end)
			return ok and isDescendant
		end
		for flag in pairs(self._window._flags) do
			local control = self._window._flags[flag]
			if tostring(flag):sub(1, #prefix) == prefix or belongsToPanel(control) then
				self._window._flags[flag] = nil
				self._window._values[flag] = nil
			end
		end
		for _, list in ipairs({ self._window._controls, self._window._keybinds }) do
			for index = #list, 1, -1 do
				local control = list[index]
				if tostring(control.Flag or ""):sub(1, #prefix) == prefix or belongsToPanel(control) then table.remove(list, index) end
			end
		end
		if module.DockItem then
			module.DockItem:Destroy()
			module.DockItem = nil
		end
		if modulePanel then
			modulePanel:Destroy()
			module.Panel = nil
			module.SettingsPanel = nil
		end
	end
	function manager:_CreateContext(module)
		return contextFor(module)
	end
	function manager:_ExecuteSource(module)
		local compiler = loadstring
		if type(compiler) ~= "function" then return false, "loadstring is unavailable in this executor." end
		local compileOk, chunk, compileError = pcall(compiler, module.Source)
		if not compileOk then return false, tostring(chunk) end
		if type(chunk) ~= "function" then return false, tostring(compileError or "Module compilation failed.") end
		local runOk, result = pcall(chunk, self._window, self, contextFor(module))
		if not runOk then return false, tostring(result) end
		return true, result
	end
	function manager:LoadModule(name)
		local module = type(name) == "table" and name or findModule(name)
		if not module then return false, "Module not found: " .. tostring(name) end
		if module.Loaded then
			if module.Definition and not module.Panel then self:_BuildSettingsPanel(module) end
			return true, module.Definition or module.LastResult
		end
		if module.Definition then
			module.Loaded = true
			normalizeModuleSettings(module)
			self:_BuildSettingsPanel(module)
			return true, module.Definition
		end
		local ok, result = self:_ExecuteSource(module)
		if not ok then return false, result end
		module.Loaded = true
		module.LastResult = result
		if type(result) == "table" then
			module.Definition = result
			normalizeModuleSettings(module)
			self:_BuildSettingsPanel(module)
			self:Refresh()
			return true, result
		end
		module.Legacy = true
		self:Refresh()
		return true, result
	end
	function manager:OpenModule(name)
		local module = findModule(name)
		if not module then return false, "Module not found: " .. tostring(name) end
		if not module.Panel then return false, "Enable a module definition once to load its window." end
		module.Panel:SetVisible(true)
		return true, module.Panel
	end
	function manager:OpenSettings(name) return self:OpenModule(name) end
	function manager:GetModule(name)
		return findModule(name)
	end
	function manager:SetModuleEnabled(name, enabled)
		if enabled == false then return self:DisableModule(name) end
		return self:EnableModule(name)
	end
	function manager:EnableModule(name)
		local module = findModule(name)
		if not module then return false, "Module not found: " .. tostring(name) end
		if module.Enabled then return true, "Already enabled." end
		local loaded, result = self:LoadModule(module)
		if not loaded then return false, result end
		if type(module.Definition) ~= "table" then
			return false, "This source did not return a module definition; use Run for one-shot scripts."
		end
		local context = contextFor(module)
		local callback = getDefinitionMember(module.Definition, "OnEnable", "onEnable", "Enable", "enable")
		module.Enabled = true
		context.Enabled = true
		local ok, message = callModuleCallback(callback, context, self._window, self)
		if not ok then
			module.Enabled = false
			context.Enabled = false
			return false, message
		end
		self:Refresh()
		return true, "Enabled " .. module.Name
	end
	function manager:DisableModule(name)
		local module = findModule(name)
		if not module then return false, "Module not found: " .. tostring(name) end
		if not module.Enabled then return true, "Already disabled." end
		local context = contextFor(module)
		local callback = getDefinitionMember(module.Definition or {}, "OnDisable", "onDisable", "Disable", "disable")
		local ok, message = callModuleCallback(callback, context, self._window, self)
		module.Enabled = false
		context.Enabled = false
		self:Refresh()
		return ok, ok and ("Disabled " .. module.Name) or message
	end
	function manager:Refresh()
		for _, child in ipairs(rows:GetChildren()) do
			if child:IsA("GuiObject") then child:Destroy() end
		end
		if #self.Modules == 0 then
			label(rows, "No modules added yet.", self._window.Theme, { size = UDim2.new(1, -4, 0, 22), position = UDim2.fromOffset(2, 0), color = self._window.Theme.muted, textSize = 11 })
			return
		end
		for _, module in ipairs(self.Modules) do
			local rowModule = module
			local row = create("Frame", {
				Name = "ModuleRow",
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundColor3 = self._window.Theme.inline,
				BorderSizePixel = 0,
			}, rows)
			label(row, rowModule.Name, self._window.Theme, {
				size = UDim2.fromOffset(105, 30),
				position = UDim2.fromOffset(5, 0),
				textSize = 11,
				truncate = true,
			})
			label(row, rowModule.Enabled and "Enabled" or (rowModule.Definition and "Disabled" or (rowModule.Legacy and "Script" or "Idle")), self._window.Theme, {
				position = UDim2.fromOffset(108, 0),
				size = UDim2.fromOffset(48, 30),
				textSize = 9,
				color = rowModule.Enabled and self._window.Theme.positive or self._window.Theme.muted,
				truncate = true,
			})
			local enableButton = button(row, rowModule.Enabled and "Disable" or "Enable", self._window.Theme, {
				position = UDim2.fromOffset(158, 3),
				size = UDim2.fromOffset(52, 24),
				textSize = 10,
				background = self._window.Theme.outline,
				border = self._window.Theme.border,
			})
			enableButton.Activated:Connect(function()
				local ok, result
				if rowModule.Enabled then ok, result = self:DisableModule(rowModule.Name)
				else ok, result = self:EnableModule(rowModule.Name) end
				if ok then
					setStatus(result, self._window.Theme.positive)
				else
					setStatus(tostring(result), self._window.Theme.warning)
				end
			end)
			local settingsButton = button(row, "Open", self._window.Theme, {
				position = UDim2.fromOffset(212, 3),
				size = UDim2.fromOffset(56, 24),
				textSize = 9,
				background = self._window.Theme.outline,
				border = self._window.Theme.border,
			})
			settingsButton.Activated:Connect(function()
				local ok, result = self:OpenModule(rowModule.Name)
				if not ok then setStatus(result, self._window.Theme.warning) end
			end)
			local runButton = button(row, "Run", self._window.Theme, {
				position = UDim2.fromOffset(270, 3),
				size = UDim2.fromOffset(38, 24),
				textSize = 10,
				background = self._window.Theme.outline,
				border = self._window.Theme.border,
			})
			runButton.Visible = rowModule.Definition == nil
			runButton.Activated:Connect(function()
				local ok, result = self:RunModule(rowModule.Name)
				if ok then setStatus("Ran " .. rowModule.Name, self._window.Theme.positive)
				else setStatus(tostring(result), self._window.Theme.negative) end
			end)
			local removeButton = button(row, "Del", self._window.Theme, {
				position = UDim2.fromOffset(310, 3),
				size = UDim2.fromOffset(38, 24),
				textSize = 10,
				background = self._window.Theme.outline,
				border = self._window.Theme.border,
				color = self._window.Theme.negative,
			})
			removeButton.Activated:Connect(function()
				local ok, result = self:RemoveModule(rowModule.Name)
				if not ok then setStatus(result, self._window.Theme.negative); return end
				setStatus("Removed " .. rowModule.Name)
			end)
		end
	end
	function manager:AddModule(name, source, moduleOptions)
		local config = copySettings(moduleOptions)
		if type(name) == "table" then
			config = copySettings(name)
			name = config.name or config.Name
			source = config.source or config.Source
		elseif type(source) == "table" then
			config = copySettings(source)
			source = config.source or config.Source
		end
		name = tostring(name or config.name or config.Name or ""):gsub("^%s*(.-)%s*$", "%1")
		source = tostring(source or config.source or config.Source or "")
		local definition = config.definition or config.Definition
		if not definition and (config.settings or config.Settings or config.Window or config.window or config.Build or config.build or config.Icon or config.icon or config.Dock or config.dock or config.OnEnable or config.onEnable or config.OnDisable or config.onDisable or config.OnSettingChanged or config.onSettingChanged) then
			definition = {
				Settings = config.settings or config.Settings,
				Window = config.Window or config.window,
				Build = config.Build or config.build,
				Icon = config.Icon or config.icon,
				Dock = config.Dock or config.dock,
				OnEnable = config.OnEnable or config.onEnable,
				OnDisable = config.OnDisable or config.onDisable,
				OnSettingChanged = config.OnSettingChanged or config.onSettingChanged,
			}
		end
		if type(source) ~= "string" then source = tostring(source or "") end
		if name == "" then return false, "Enter a module name." end
		if source:gsub("%s", "") == "" and type(definition) ~= "table" then return false, "Enter Lua source or a module definition first." end
		local existingModule = findModule(name)
		local module = existingModule
		if module and module.Enabled then self:DisableModule(module.Name) end
		if module then self:_DestroySettingsPanel(module) end
		if not module then
			self._nextModuleId = self._nextModuleId + 1
			module = { Name = name, Id = self._nextModuleId, Values = {}, Enabled = false }
			table.insert(self.Modules, module)
		end
		module.Source = source
		module.Definition = definition
		module.StaticSettings = config.settings or config.Settings
		module.Icon = config.icon or config.Icon
		module.Loaded = type(definition) == "table"
		module.Legacy = false
		module.LastResult = nil
		module.SettingsPanel = nil
		module.Context = nil
		if module.Loaded then normalizeModuleSettings(module); self:_BuildSettingsPanel(module) end
		self:Refresh()
		return true, existingModule and "Updated " .. name or "Added " .. name, module
	end
	function manager:RemoveModule(name)
		local module = type(name) == "table" and name or findModule(name)
		if not module then return false, "Module not found: " .. tostring(name) end
		if module.Enabled then self:DisableModule(module.Name) end
		self:_DestroySettingsPanel(module)
		for index, candidate in ipairs(self.Modules) do
			if candidate == module then table.remove(self.Modules, index); self:Refresh(); return true end
		end
		return false, "Module not found: " .. tostring(name)
	end
	function manager:GetModules()
		local result = {}
		for _, module in ipairs(self.Modules) do
			table.insert(result, {
				Name = module.Name,
				Source = module.Source,
				Enabled = module.Enabled == true,
				Settings = copyValue(module.Values),
			})
		end
		return result
	end
	function manager:RunModule(name)
		local module = findModule(name)
		if not module then return false, "Module not found: " .. tostring(name) end
		if module.Definition then return self:EnableModule(module.Name) end
		if module.Loaded and module.Legacy then
			local ok, result = self:_ExecuteSource(module)
			if not ok then return false, result end
			module.LastResult = result
			return true, result
		end
		local loaded, result = self:LoadModule(module)
		if not loaded then return false, result end
		if module.Definition then return self:EnableModule(module.Name) end
		return true, result
	end
	function manager:Destroy()
		for _, module in ipairs(self.Modules) do
			if module.Enabled then self:DisableModule(module.Name) end
			self:_DestroySettingsPanel(module)
			module.Context = nil
		end
		if self.Panel then self.Panel:Destroy() end
		if self._window._luaModuleManager == self then self._window._luaModuleManager = nil end
		if self._window.LuaModules == self then self._window.LuaModules = nil end
	end
	addButton.Activated:Connect(function()
		local ok, message = manager:AddModule(nameInput.Text, sourceInput.Text)
		if ok then
			nameInput.Text, sourceInput.Text = "", ""
			setStatus(message, self.Theme.positive)
		else
			setStatus(message, self.Theme.negative)
		end
	end)
	for _, module in ipairs(manager.Modules) do
		local id = tonumber(module.Id)
		if not id then
			manager._nextModuleId = manager._nextModuleId + 1
			module.Id = manager._nextModuleId
		elseif id > manager._nextModuleId then
			manager._nextModuleId = id
		end
		module.Values = module.Values or {}
		module.Context = nil
		if module.Definition then
			module.Loaded = true
			manager:_BuildSettingsPanel(module)
		end
	end
	manager:Refresh()
	if self.Dock then self.Dock:Refresh() end
	return manager
end

function BacktrackUI:CreateWatermark(text, options)
	options = options or {}
	local watermarkGui = create("ScreenGui", {
		Name = self.Gui.Name .. "_Watermark",
		ResetOnSpawn = false,
		IgnoreGuiInset = options.ignoreGuiInset == true,
		DisplayOrder = options.displayOrder or self._options.displayOrder or 100,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, self.Gui.Parent)
	GuiThemes[watermarkGui] = self.Theme
	local badge = create("Frame", {
		Name = "Watermark",
		Position = options.position or UDim2.fromOffset(31, 0),
		Size = UDim2.fromOffset(50, 29),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = self.Theme.outline,
		BorderSizePixel = 0,
		Active = true,
	}, watermarkGui)
	local outerInline = create("Frame", {
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = self.Theme.inline,
		BorderSizePixel = 0,
	}, badge)
	local outerSurface = create("Frame", {
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = self.Theme.contrastTop,
		BorderSizePixel = 0,
	}, outerInline)
	gradient(outerSurface, self.Theme.contrastTop, self.Theme.contrastBottom)
	local innerInline = create("Frame", {
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6),
		BackgroundColor3 = self.Theme.inline,
		BorderSizePixel = 0,
	}, outerSurface)
	local innerSurface = create("Frame", {
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = self.Theme.contrastTop,
		BorderSizePixel = 0,
	}, innerInline)
	gradient(innerSurface, self.Theme.contrastTop, self.Theme.contrastBottom)
	local accent = create("Frame", {
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = self.Theme.accent,
		BorderSizePixel = 0,
	}, innerSurface)
	local accentGradient = gradient(accent, Color3.fromRGB(255, 255, 255), Color3.fromRGB(167, 167, 167))
	accentGradient.Name = "WatermarkAccentGradient"
	create("UIPadding", {
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 9),
	}, accent)
	local textLabel = label(accent, text or "backtrack.tech", self.Theme, {
		name = "WatermarkText",
		position = UDim2.new(0, 0, 0, 9),
		size = UDim2.new(0, 0, 0, 14),
		textSize = 12,
		color = self.Theme.text,
		automaticSize = Enum.AutomaticSize.X,
	})
	create("UIStroke", { LineJoinMode = Enum.LineJoinMode.Miter }, textLabel)
	local connections = {}
	local function listen(signal, callback)
		local connection = signal:Connect(callback)
		table.insert(connections, connection)
		return connection
	end
	local start, inputStart
	listen(badge.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			start, inputStart = badge.Position, input.Position
		end
	end)
	listen(UserInputService.InputChanged, function(input)
		if start and inputStart and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - inputStart
			badge.Position = UDim2.new(start.X.Scale, start.X.Offset + delta.X, start.Y.Scale, start.Y.Offset + delta.Y)
		end
	end)
	listen(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			start, inputStart = nil, nil
		end
	end)
	local handle = {
		_window = self,
		Gui = watermarkGui,
		Object = badge,
		Text = textLabel,
		SetText = function(_, value) textLabel.Text = tostring(value or "") end,
		SetVisible = function(_, visible) badge.Visible = visible ~= false end,
		SetPosition = function(_, position) badge.Position = position end,
		GetPosition = function() return badge.Position end,
	}
	function handle:Destroy()
		if self._destroyed then return end
		self._destroyed = true
		for _, connection in ipairs(connections) do connection:Disconnect() end
		table.clear(connections)
		if self.Gui and self.Gui.Parent then self.Gui:Destroy() end
		for index, watermark in ipairs(self._window._watermarks) do
			if watermark == self then table.remove(self._window._watermarks, index) break end
		end
	end
	table.insert(self._watermarks, handle)
	return handle
end

function BacktrackUI:CreateDock(options)
	options = options or {}
	if self.Dock and self.Dock.Frame.Parent then self.Dock:Destroy() end
	self.Dock = nil
	local dockTheme = mergeTheme(options.theme, self.Theme)
	local buttonSize = options.buttonSize or 25
	local buttonSizeUDim = typeof(buttonSize) == "UDim2" and buttonSize or UDim2.fromOffset(buttonSize, buttonSize)
	local spacing = options.spacing or 5
	local paddingX = options.paddingX or options.padding or 4
	local paddingTop = options.paddingTop or 6
	local paddingBottom = options.paddingBottom or 4
	local dockHeight = options.height or 39
	local dock = {
		_window = self,
		_items = {},
		_buttons = {},
		_buttonConnections = {},
		_buttonTooltipCloses = {},
		_dragConnections = {},
		Theme = dockTheme,
		Options = options,
		ButtonSize = buttonSizeUDim,
		Spacing = spacing,
		PaddingX = paddingX,
		PaddingTop = paddingTop,
		PaddingBottom = paddingBottom,
		Height = dockHeight,
		AutoSize = options.size == nil,
	}
	dock.Items = dock._items
	dock.Tabs = dock._items
	local frame = create("Frame", {
		Name = options.name or "BacktrackDock",
		AnchorPoint = options.anchorPoint or Vector2.new(0.5, 0),
		Position = options.position or UDim2.new(0.5, 0, 1, -120),
		Size = options.size or UDim2.fromOffset(paddingX * 2, dockHeight),
		BackgroundColor3 = options.backgroundColor or dockTheme.outline,
		BackgroundTransparency = options.backgroundTransparency or 0,
		BorderSizePixel = 0,
		Active = true,
		Visible = options.visible ~= false,
		ZIndex = 10,
	}, self:_getOverlayGui())
	dock.Frame = frame
	local glowImage = options.glowImage or self.Images.glow4 or self.Images.glow
	if glowImage and options.showGlow ~= false then
		create("ImageLabel", {
			Name = "DockGlow",
			Position = UDim2.fromOffset(-20, -20),
			Size = UDim2.new(1, 40, 1, 40),
			BackgroundTransparency = 1,
			Image = glowImage,
			ImageColor3 = options.glowColor or dockTheme.glow,
			ImageTransparency = options.glowTransparency or 0.8,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(21, 21, 79, 79),
			ZIndex = 9,
		}, frame)
	end
	local inline = create("Frame", {
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = options.inlineColor or dockTheme.inline,
		BorderSizePixel = 0,
		ZIndex = 11,
	}, frame)
	dock.Inline = inline
	local face = create("Frame", {
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = options.surfaceColor or dockTheme.contrastTop,
		BorderSizePixel = 0,
		ZIndex = 12,
	}, inline)
	dock.Surface = face
	gradient(face, options.surfaceColor or dockTheme.contrastTop, options.surfaceBottomColor or dockTheme.contrastBottom)
	dock.AccentCap = create("Frame", {
		Name = "PinkCap",
		Size = options.capSize or UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = options.accentColor or dockTheme.accent,
		BorderSizePixel = 0,
		ZIndex = 13,
	}, face)
	local holder = create("Frame", {
		Name = "DockButtons",
		Position = UDim2.new(),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 14,
	}, face)
	dock.Holder = holder
	dock.Layout = create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = options.sortOrder or Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, spacing),
	}, holder)
	create("UIPadding", {
		PaddingTop = UDim.new(0, paddingTop),
		PaddingBottom = UDim.new(0, paddingBottom),
		PaddingLeft = UDim.new(0, paddingX),
		PaddingRight = UDim.new(0, paddingX),
	}, holder)
	local dragStart, positionStart
	local function listenDock(signal, callback)
		local connection = signal:Connect(callback)
		table.insert(dock._dragConnections, connection)
		return connection
	end
	listenDock(frame.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragStart, positionStart = input.Position, frame.Position
		end
	end)
	listenDock(UserInputService.InputChanged, function(input)
		if dragStart and positionStart and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(positionStart.X.Scale, positionStart.X.Offset + delta.X, positionStart.Y.Scale, positionStart.Y.Offset + delta.Y)
		end
	end)
	listenDock(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragStart = nil end
	end)
	local function updateSize()
		if not dock.AutoSize then return end
		local count, width = 0, paddingX * 2
		for _, tab in ipairs(dock._items) do
			if not tab._destroyed and tab.Button.Visible then
				count = count + 1
				local size = tab.Button.Size
				width = width + (size.X.Scale == 0 and size.X.Offset or buttonSizeUDim.X.Offset)
			end
		end
		if count > 1 then width = width + (count - 1) * spacing end
		frame.Size = UDim2.fromOffset(width, dock.Height)
	end

	local function copyOptions(source)
		local result = {}
		for key, value in pairs(source or {}) do result[key] = value end
		return result
	end

	function dock:AddTab(name, icon, callback, itemOptions)
		local config
		if type(name) == "table" then
			config = copyOptions(name)
		else
			config = copyOptions(itemOptions)
			config.name = name
			config.icon = icon
			config.callback = callback
		end
		local itemName = tostring(config.name or ("Tab " .. tostring(#self._items + 1)))
		local itemTheme = mergeTheme(config.theme, self.Theme)
		local itemSize = config.size or buttonSizeUDim
		local item = create("TextButton", {
			Name = config.objectName or "DockButton",
			Size = itemSize,
			BackgroundColor3 = config.backgroundColor or itemTheme.inline,
			BorderSizePixel = config.borderSizePixel or 0,
			Text = "",
			AutoButtonColor = config.autoButtonColor == true,
			Visible = config.visible ~= false,
			ZIndex = config.zIndex or 15,
		}, holder)
		local itemZ = item.ZIndex
		local outline = create("Frame", {
			Name = "Outline",
			Position = config.outlinePosition or UDim2.fromOffset(1, 1),
			Size = config.outlineSize or UDim2.new(1, -2, 1, -2),
			BackgroundColor3 = config.outlineColor or itemTheme.outline,
			BorderSizePixel = 0,
			ZIndex = itemZ + 1,
		}, item)
		local iconFace = create("Frame", {
			Name = "Face",
			Position = config.facePosition or UDim2.fromOffset(1, 1),
			Size = config.faceSize or UDim2.new(1, -2, 1, -2),
			BackgroundColor3 = config.surfaceColor or itemTheme.contrastBottom,
			BorderSizePixel = 0,
			ZIndex = itemZ + 2,
		}, outline)
		gradient(iconFace, config.surfaceBottomColor or itemTheme.contrastBottom, config.surfaceTopColor or itemTheme.contrastTop)
		local cap = create("Frame", {
			Name = "AccentCap",
			Size = config.capSize or UDim2.new(1, 0, 0, 2),
			BackgroundColor3 = config.accentColor or itemTheme.accent,
			BorderSizePixel = 0,
			Visible = config.showCap == true,
			ZIndex = itemZ + 3,
		}, iconFace)
		local handle = {
			_dock = self,
			_config = config,
			Name = itemName,
			Button = item,
			Outline = outline,
			IconFrame = iconFace,
			Cap = cap,
			Icon = nil,
			_customSize = config.size ~= nil,
			_visible = config.visible ~= false,
			_order = config.order or (#self._items + 1),
			_activeOverride = config.active,
			_connections = {},
			_destroyed = false,
		}
		item:SetAttribute("DockButtonName", itemName)
		item.LayoutOrder = handle._order

		local iconLabel, iconPadding
		local function setIcon(nextIcon, iconText)
			if iconLabel then iconLabel:Destroy(); iconLabel = nil end
			if iconPadding then iconPadding:Destroy(); iconPadding = nil end
			handle.Icon = nextIcon
			local image = type(nextIcon) == "string" and (self._window.Images[nextIcon] or (nextIcon:match("^rbxassetid://") and nextIcon)) or nil
			if image then
				iconLabel = create("ImageLabel", {
					Name = "Icon",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Image = image,
					ImageColor3 = itemTheme.inline,
					ResampleMode = config.resampleMode or Enum.ResamplerMode.Pixelated,
					ScaleType = config.scaleType or Enum.ScaleType.Fit,
					ZIndex = itemZ + 3,
				}, iconFace)
				local inset = config.iconPadding or options.iconPadding or 3
				iconPadding = create("UIPadding", {
					PaddingTop = UDim.new(0, inset),
					PaddingBottom = UDim.new(0, inset),
					PaddingLeft = UDim.new(0, inset),
					PaddingRight = UDim.new(0, inset),
				}, iconFace)
			elseif iconText or nextIcon == "lua" then
				iconLabel = create("TextLabel", {
					Name = "Icon",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Font = config.iconFont or Enum.Font.Code,
					Text = tostring(iconText or (nextIcon == "lua" and "</>" or nextIcon)),
					TextSize = config.iconTextSize or 10,
					TextColor3 = itemTheme.inline,
					TextScaled = config.iconTextScaled == true,
					ZIndex = itemZ + 3,
				}, iconFace)
			end
			handle:Refresh()
		end
		local function updateTooltip(text)
			if handle._closeTooltip then handle._closeTooltip(); handle._closeTooltip = nil end
			if text ~= false and text ~= nil and text ~= "" then
				handle._closeTooltip = self._window:AddTooltip(item, tostring(text))
			end
		end
		function handle:Refresh()
			local active = self._activeOverride
			if type(active) == "function" then
				local ok, value = pcall(active)
				active = ok and value == true
			elseif active == nil then
				if type(self._config.isOpen) == "function" then
					local ok, value = pcall(self._config.isOpen)
					active = ok and value == true
				else
					active = self._config.active == true
				end
			end
			local activeColor = self._config.activeColor or itemTheme.accent
			local inactiveColor = self._config.inactiveColor or itemTheme.inline
			local color = active and activeColor or inactiveColor
			if iconLabel then
				if iconLabel:IsA("ImageLabel") then iconLabel.ImageColor3 = color
				else iconLabel.TextColor3 = color end
			end
			if self._config.buttonColor then item.BackgroundColor3 = self._config.buttonColor end
			if self._config.surfaceColor then iconFace.BackgroundColor3 = self._config.surfaceColor end
			if self._config.accentColor then cap.BackgroundColor3 = self._config.accentColor end
		end
		function handle:SetActive(active)
			self._activeOverride = active
			self:Refresh()
			return active
		end
		function handle:SetVisible(visible)
			self._visible = visible ~= false
			item.Visible = self._visible
			updateSize()
		end
		function handle:SetName(nextName)
			self.Name = tostring(nextName or "")
			item:SetAttribute("DockButtonName", self.Name)
			local tooltip = self._config.tooltip
			if tooltip == nil then tooltip = self.Name end
			updateTooltip(tooltip)
		end
		function handle:SetIcon(nextIcon, nextIconText)
			self._config.icon = nextIcon
			self._config.iconText = nextIconText
			setIcon(nextIcon, nextIconText)
		end
		function handle:SetOrder(order)
			self._order = order
			item.LayoutOrder = order
		end
		function handle:SetSize(size)
			self._customSize = true
			item.Size = size
			updateSize()
		end
		function handle:SetTooltip(text)
			self._config.tooltip = text
			updateTooltip(text)
		end
		function handle:SetStyle(style)
			for key, value in pairs(style or {}) do self._config[key] = value end
			local config = self._config
			if config.buttonColor or config.backgroundColor then item.BackgroundColor3 = config.buttonColor or config.backgroundColor end
			if config.outlineColor then outline.BackgroundColor3 = config.outlineColor end
			if config.surfaceColor then iconFace.BackgroundColor3 = config.surfaceColor end
			if config.surfaceColor or config.surfaceBottomColor or config.surfaceTopColor then
				local surfaceGradient = iconFace:FindFirstChildOfClass("UIGradient")
				if surfaceGradient then
					surfaceGradient.Color = ColorSequence.new(config.surfaceBottomColor or itemTheme.contrastBottom,
						config.surfaceTopColor or config.surfaceColor or itemTheme.contrastTop)
				end
			end
			if config.accentColor then cap.BackgroundColor3 = config.accentColor end
			if config.capSize then cap.Size = config.capSize end
			if config.showCap ~= nil then cap.Visible = config.showCap end
			if config.size then self:SetSize(config.size) end
			if config.zIndex then item.ZIndex = config.zIndex end
			if config.autoButtonColor ~= nil then item.AutoButtonColor = config.autoButtonColor end
			if config.icon ~= nil or config.image ~= nil or config.iconText ~= nil then
				setIcon(config.icon or config.image, config.iconText)
			else
				self:Refresh()
			end
		end
		function handle:Destroy()
			if self._destroyed then return end
			self._destroyed = true
			for _, connection in ipairs(self._connections) do connection:Disconnect() end
			table.clear(self._connections)
			if self._closeTooltip then self._closeTooltip(); self._closeTooltip = nil end
			if item.Parent then item:Destroy() end
			for index, candidate in ipairs(self._dock._items) do
				if candidate == self then table.remove(self._dock._items, index) break end
			end
			for index, candidate in ipairs(self._dock._buttons) do
				if candidate == item then table.remove(self._dock._buttons, index) break end
			end
			updateSize()
		end

		setIcon(config.icon or config.image, config.iconText)
		local tooltip = config.tooltip
		if tooltip == nil then tooltip = itemName end
		updateTooltip(tooltip)
		for _, signal in ipairs(config.stateSignals or {}) do
			local ok, connection = pcall(function() return signal:Connect(function() handle:Refresh() end) end)
			if ok and connection then table.insert(handle._connections, connection) end
		end
		item.Activated:Connect(function()
			if type(config.callback) == "function" then invoke(config.callback, self._window, handle) end
			handle:Refresh()
		end)
		table.insert(self._items, handle)
		table.insert(self._buttons, item)
		handle:Refresh()
		updateSize()
		return handle
	end
	function dock:AddButton(name, icon, callback, isOpen, stateSignals, itemOptions)
		if type(name) == "table" then return self:AddTab(name).Button end
		if type(isOpen) == "table" and stateSignals == nil and itemOptions == nil then
			itemOptions = isOpen
			isOpen = itemOptions.isOpen
			stateSignals = itemOptions.stateSignals
		end
		local config = copyOptions(itemOptions)
		config.name, config.icon, config.callback = name, icon, callback
		if isOpen ~= nil then config.isOpen = isOpen end
		if stateSignals ~= nil then config.stateSignals = stateSignals end
		return self:AddTab(config).Button
	end
	function dock:AddWindow(name, target, icon, itemOptions)
		local config
		if type(name) == "table" then
			config = copyOptions(name)
			target = config.target or config.window
		else
			config = copyOptions(itemOptions)
			config.name = name
			config.icon = icon
		end
		if target == nil or target == self._window then
			config.callback = function()
				local window = self._window
				local opening = not (window.Gui.Enabled and window.Outer.Visible)
				window.Gui.Enabled = opening
				if opening then
					window.Outer.Visible = true
					window._nextDisplayOrder = window._nextDisplayOrder + 1
					window.Gui.DisplayOrder = window._nextDisplayOrder
				end
				window:_syncCursor()
			end
			config.isOpen = function()
				local window = self._window
				return window.Gui.Enabled and window.Outer.Visible
			end
			config.stateSignals = {
				self._window.Gui:GetPropertyChangedSignal("Enabled"),
				self._window.Outer:GetPropertyChangedSignal("Visible"),
			}
			config.icon = config.icon or "main"
			config.name = config.name or "Main"
		else
			local targetPanel = target
			config.callback = function()
				if type(targetPanel.Toggle) == "function" then
					targetPanel:Toggle()
				elseif targetPanel.Gui then
					targetPanel.Gui.Enabled = not targetPanel.Gui.Enabled
				end
			end
			config.isOpen = function() return targetPanel.Gui and targetPanel.Gui.Enabled == true end
			config.stateSignals = targetPanel.Gui and { targetPanel.Gui:GetPropertyChangedSignal("Enabled") } or {}
			config.icon = config.icon or targetPanel.Image
			config.name = config.name or targetPanel.Name or "Window"
		end
		return self:AddTab(config)
	end
	function dock:AddPanel(panel, itemOptions)
		assert(type(panel) == "table", "dock:AddPanel expects a panel returned by CreatePanel")
		itemOptions = copyOptions(itemOptions)
		itemOptions.name = itemOptions.name or (panel and panel.Name)
		itemOptions.icon = itemOptions.icon or (panel and panel.Image)
		return self:AddWindow(itemOptions.name, panel, itemOptions.icon, itemOptions)
	end
	dock.AddDockTab = dock.AddTab
	dock.AddDockButton = dock.AddButton
	dock.add_tab = dock.AddTab
	dock.add_button = dock.AddButton
	dock.add_window = dock.AddWindow
	dock.add_panel = dock.AddPanel
	function dock:RemoveTab(reference)
		for _, item in ipairs(self._items) do
			if item == reference or item.Button == reference or item.Name == reference then
				item:Destroy()
				return true
			end
		end
		return false
	end
	dock.RemoveButton = dock.RemoveTab
	function dock:Clear()
		while #self._items > 0 do self._items[1]:Destroy() end
	end
	function dock:Refresh()
		for _, item in ipairs(self._items) do item:Refresh() end
		updateSize()
	end
	function dock:SetSpacing(value)
		spacing = math.max(0, tonumber(value) or spacing)
		dock.Spacing = spacing
		dock.Options.spacing = spacing
		for _, child in ipairs(holder:GetChildren()) do
			if child:IsA("UIListLayout") then child.Padding = UDim.new(0, spacing) break end
		end
		updateSize()
	end
	function dock:SetButtonSize(value)
		buttonSizeUDim = typeof(value) == "UDim2" and value or UDim2.fromOffset(value, value)
		dock.ButtonSize = buttonSizeUDim
		dock.Options.buttonSize = value
		for _, tab in ipairs(self._items) do
			if not tab._customSize then tab.Button.Size = buttonSizeUDim end
		end
		updateSize()
	end
	function dock:SetPosition(position)
		frame.Position = position
		dock.Options.position = position
	end
	function dock:SetSize(size)
		dock.AutoSize = false
		frame.Size = size
		dock.Options.size = size
	end
	function dock:FitContent()
		dock.AutoSize = true
		dock.Options.size = nil
		updateSize()
	end
	function dock:SetStyle(style)
		for key, value in pairs(style or {}) do self.Options[key] = value end
		local config = self.Options
		if config.name then frame.Name = config.name end
		if config.position then frame.Position = config.position end
		if config.anchorPoint then frame.AnchorPoint = config.anchorPoint end
		if config.backgroundColor then frame.BackgroundColor3 = config.backgroundColor end
		if config.backgroundTransparency ~= nil then frame.BackgroundTransparency = config.backgroundTransparency end
		if config.inlineColor then inline.BackgroundColor3 = config.inlineColor end
		if config.surfaceColor then face.BackgroundColor3 = config.surfaceColor end
		if config.surfaceColor or config.surfaceBottomColor then
			local surfaceGradient = face:FindFirstChildOfClass("UIGradient")
			if surfaceGradient then
				surfaceGradient.Color = ColorSequence.new(config.surfaceColor or dockTheme.contrastTop,
					config.surfaceBottomColor or dockTheme.contrastBottom)
			end
		end
		if config.accentColor then dock.AccentCap.BackgroundColor3 = config.accentColor end
		if config.capSize then dock.AccentCap.Size = config.capSize end
		local glow = frame:FindFirstChild("DockGlow")
		if glow and config.showGlow ~= nil then glow.Visible = config.showGlow end
		if glow and config.glowColor then glow.ImageColor3 = config.glowColor end
		if glow and config.glowTransparency then glow.ImageTransparency = config.glowTransparency end
		if config.buttonSize then self:SetButtonSize(config.buttonSize) end
		if config.spacing then self:SetSpacing(config.spacing) end
		if config.visible ~= nil then self:SetVisible(config.visible) end
		if config.size then self:SetSize(config.size) end
	end
	function dock:SetVisible(visible)
		frame.Visible = visible ~= false
		self.Options.visible = frame.Visible
		self._window:_syncCursor()
	end
	function dock:Toggle()
		self:SetVisible(not frame.Visible)
		return frame.Visible
	end
	function dock:Destroy()
		if self._destroyed then return end
		self._destroyed = true
		self:Clear()
		for _, connection in ipairs(self._dragConnections) do connection:Disconnect() end
		table.clear(self._dragConnections)
		for _, connection in ipairs(self._buttonConnections) do connection:Disconnect() end
		table.clear(self._buttonConnections)
		for _, closeTooltip in ipairs(self._buttonTooltipCloses) do closeTooltip() end
		table.clear(self._buttonTooltipCloses)
		if frame.Parent then frame:Destroy() end
		if self._window.Dock == self then self._window.Dock = nil end
		self._window:_syncCursor()
	end
	self.Dock = dock
	if self._luaModuleManager and type(self._luaModuleManager._AttachDock) == "function" then
		self._luaModuleManager:_AttachDock(dock)
	end
	self:_syncCursor()
	return dock
end

function BacktrackUI:Destroy()
	if self._destroyed then return end
	self._destroyed = true
	if self._themeRefreshConnection then
		self._themeRefreshConnection:Disconnect()
		self._themeRefreshConnection = nil
	end
	if self.Dock then self.Dock:Destroy(); self.Dock = nil end
	self:_restoreCursor()
	self:_closePopup()
	while #self._watermarks > 0 do
		self._watermarks[1]:Destroy()
	end
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
	for _, panel in ipairs(self._panels) do
		if panel.Gui and panel.Gui.Parent then panel.Gui:Destroy() end
	end
	table.clear(self._panels)
	if self.OverlayGui and self.OverlayGui.Parent then self.OverlayGui:Destroy() end
	if self.Gui then self.Gui:Destroy() end
end

local Tab = {}
Tab.__index = Tab
Column = {}
Column.__index = Column
local MultiSection = {}
MultiSection.__index = MultiSection
local Section = {}
Section.__index = Section

function BacktrackUI:AddTab(name, iconText)
	local tabOptions
	if type(name) == "table" then
		tabOptions = name
	else
		tabOptions = { name = name, iconText = iconText }
	end
	local index = #self._tabs + 1
	local tab = setmetatable({
		_window = self,
		Name = tabOptions.name or tabOptions.title or ("Tab " .. index),
		Options = tabOptions,
		Icon = tabOptions.icon or tabOptions.image,
		_visible = tabOptions.visible ~= false,
		_columns = {},
		_sectionCount = 0,
	}, Tab)
	tab.Button = create("TextButton", {
		Name = tabOptions.objectName or "TabButton",
		AutoButtonColor = tabOptions.autoButtonColor == true,
		Size = tabOptions.size or UDim2.new(0, tabOptions.width or 0, 1, -2),
		BackgroundColor3 = tabOptions.buttonColor or self.Theme.outline,
		BorderSizePixel = 0,
		Text = "",
		Visible = tab._visible,
		LayoutOrder = tabOptions.order or index,
		ZIndex = 5,
	}, self.TabBar)
	tab.Inline = create("Frame", {
		Name = "Inline",
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, 0),
		BackgroundColor3 = tabOptions.inlineColor or self.Theme.inline,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, tab.Button)
	tab.Face = create("Frame", {
		Name = "Face",
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -1),
		BackgroundColor3 = tabOptions.surfaceColor or self.Theme.contrastTop,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, tab.Inline)
	tab.FaceGradient = gradient(tab.Face, tabOptions.surfaceColor or self.Theme.contrastTop, tabOptions.surfaceBottomColor or self.Theme.contrastBottom)
	tab.Label = label(tab.Face, tabOptions.text or tab.Name, self.Theme, {
		name = "TabLabel",
		position = tabOptions.labelPosition or UDim2.new(),
		size = tabOptions.labelSize or UDim2.new(1, 0, 1, 0),
		textSize = tabOptions.textSize or 12,
		align = tabOptions.textAlign or Enum.TextXAlignment.Center,
		color = tabOptions.textColor or self.Theme.text,
		font = tabOptions.font,
		zIndex = 6,
	})
	tab.Page = create("Frame", {
		Name = tabOptions.pageName or "Page_" .. tostring(index),
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
	}, self.TabPages)
	tab.Grid = tab.Page
	create("UIListLayout", {
		Name = "ColumnsLayout",
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalFlex = Enum.UIFlexAlignment.Fill,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, tab.Page)
	create("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
	}, tab.Page)
	local function setTabIcon(icon, text)
		if tab.IconLabel then tab.IconLabel:Destroy(); tab.IconLabel = nil end
		tab.Icon = icon
		tabOptions.icon = icon
		tabOptions.iconText = text
		local image = type(icon) == "string" and (self.Images[icon] or (icon:match("^rbxassetid://") and icon)) or nil
		if image then
			tab.IconLabel = create("ImageLabel", {
				Name = "TabIcon",
				Position = tabOptions.iconPosition or UDim2.fromOffset(5, 3),
				Size = tabOptions.iconSizeUDim2 or UDim2.fromOffset(tabOptions.iconSize or 14, tabOptions.iconSize or 14),
				BackgroundTransparency = 1,
				Image = image,
				ImageColor3 = tabOptions.iconColor or self.Theme.text,
				ResampleMode = tabOptions.resampleMode or Enum.ResamplerMode.Pixelated,
				ZIndex = 6,
			}, tab.Face)
		elseif text then
			tab.IconLabel = label(tab.Face, text, self.Theme, {
				name = "TabIcon",
				position = tabOptions.iconPosition or UDim2.fromOffset(4, 0),
				size = tabOptions.iconSizeUDim2 or UDim2.fromOffset(tabOptions.iconWidth or 18, tabOptions.iconHeight or 20),
				font = tabOptions.iconFont or Enum.Font.Code,
				textSize = tabOptions.iconTextSize or 11,
				align = Enum.TextXAlignment.Center,
				color = tabOptions.iconColor or self.Theme.text,
				zIndex = 6,
			})
		end
		if tab.IconLabel then
			tab.Label.Position = tabOptions.labelPosition or UDim2.fromOffset(tabOptions.labelOffset or 22, 0)
			tab.Label.Size = tabOptions.labelSize or UDim2.new(1, -(tabOptions.labelOffset or 22), 1, 0)
			tab.Label.TextXAlignment = tabOptions.textAlign or Enum.TextXAlignment.Left
		end
		tab.Label.Visible = tabOptions.showName ~= false
		if not tab.IconLabel then
			tab.Label.Position = tabOptions.labelPosition or UDim2.new()
			tab.Label.Size = tabOptions.labelSize or UDim2.new(1, 0, 1, 0)
			tab.Label.TextXAlignment = tabOptions.textAlign or Enum.TextXAlignment.Center
		end
	end
	function tab:_updateStyle(selected)
		local inactiveText = self.Options.textColor or self._window.Theme.text
		local activeText = self.Options.activeColor or self._window.Theme.accent
		local inactiveIcon = self.Options.iconColor or inactiveText
		local activeIcon = self.Options.activeIconColor or activeText
		self.Label.TextColor3 = selected and activeText or inactiveText
		if self.IconLabel then
			if self.IconLabel:IsA("ImageLabel") then
				self.IconLabel.ImageColor3 = selected and activeIcon or inactiveIcon
			else
				self.IconLabel.TextColor3 = selected and activeIcon or inactiveIcon
			end
		end
		self.Face.Size = selected and (self.Options.activeFaceSize or UDim2.new(1, -2, 1, 0)) or (self.Options.inactiveFaceSize or UDim2.new(1, -2, 1, -1))
		self.FaceGradient.Rotation = selected and (self.Options.activeGradientRotation or -90) or (self.Options.inactiveGradientRotation or 90)
		self.Face.BackgroundColor3 = selected and (self.Options.activeSurfaceColor or self.Options.surfaceColor or self._window.Theme.contrastTop)
			or (self.Options.surfaceColor or self._window.Theme.contrastTop)
	end
	function tab:SetName(nextName)
		self.Name = tostring(nextName or "")
		if self.Options.text == nil then self.Label.Text = self.Name end
		return self.Name
	end
	function tab:SetText(nextText)
		self.Options.text = tostring(nextText or "")
		self.Label.Text = self.Options.text
		return self.Options.text
	end
	function tab:SetIcon(icon, text)
		setTabIcon(icon, text)
		if self._updateStyle then self:_updateStyle(self._window.ActiveTab == self) end
	end
	function tab:SetCallback(callback)
		self.Options.callback = callback
	end
	function tab:SetStyle(style)
		for key, value in pairs(style or {}) do self.Options[key] = value end
		local config = self.Options
		if config.buttonColor then self.Button.BackgroundColor3 = config.buttonColor end
		if config.inlineColor then self.Inline.BackgroundColor3 = config.inlineColor end
		if config.surfaceColor then self.Face.BackgroundColor3 = config.surfaceColor end
		if config.surfaceColor or config.surfaceBottomColor then
			self.FaceGradient.Color = ColorSequence.new(config.surfaceColor or self._window.Theme.contrastTop,
				config.surfaceBottomColor or self._window.Theme.contrastBottom)
		end
		if config.textSize then self.Label.TextSize = config.textSize end
		if config.font then self.Label.Font = config.font end
		if config.textAlign then self.Label.TextXAlignment = config.textAlign end
		if config.text ~= nil then self.Label.Text = tostring(config.text) end
		if config.size then self.Button.Size = config.size
		elseif config.width then self.Button.Size = UDim2.new(0, config.width, 1, -2) end
		if config.order then self.Button.LayoutOrder = config.order end
		if config.showName ~= nil then self.Label.Visible = config.showName end
		if config.visible ~= nil then self:SetVisible(config.visible) end
		if config.iconColor and self.IconLabel then
			if self.IconLabel:IsA("ImageLabel") then self.IconLabel.ImageColor3 = config.iconColor
			else self.IconLabel.TextColor3 = config.iconColor end
		end
		if config.iconSize or config.iconSizeUDim2 or config.iconWidth or config.iconHeight or config.iconPosition
			or config.iconFont or config.iconTextSize or config.iconText ~= nil then
			setTabIcon(self.Icon, config.iconText)
		end
		self:_updateStyle(self._window.ActiveTab == self)
	end
	function tab:SetVisible(visible)
		self._visible = visible ~= false
		self.Button.Visible = self._visible
		if not self._visible then
			self.Page.Visible = false
			self:_updateStyle(false)
			if self._window.ActiveTab == self then
				self._window.ActiveTab = nil
				for _, candidate in ipairs(self._window._tabs) do
					if candidate ~= self and candidate._visible then candidate:SetActive(true); break end
				end
			end
		elseif not self._window.ActiveTab then
			self:SetActive(true)
		end
	end
	function tab:SetOrder(order)
		self.Options.order = order
		self.Button.LayoutOrder = order
	end
	function tab:SetTooltip(text)
		if self._closeTooltip then self._closeTooltip(); self._closeTooltip = nil end
		if text ~= nil and text ~= false and text ~= "" then
			self._closeTooltip = self._window:AddTooltip(self.Button, tostring(text))
		end
	end
	function tab:Destroy()
		local wasActive = self._window.ActiveTab == self
		if self._closeTooltip then self._closeTooltip(); self._closeTooltip = nil end
		for index, candidate in ipairs(self._window._tabs) do
			if candidate == self then table.remove(self._window._tabs, index) break end
		end
		if self.Button.Parent then self.Button:Destroy() end
		if self.Page.Parent then self.Page:Destroy() end
		if wasActive then self._window.ActiveTab = nil end
		for index, candidate in ipairs(self._window._tabs) do
			candidate.Button.LayoutOrder = candidate.Options.order or index
		end
		if wasActive then
			for _, candidate in ipairs(self._window._tabs) do
				if candidate._visible then candidate:SetActive(true); break end
			end
		end
	end
	setTabIcon(tab.Icon, tabOptions.iconText)
	if tabOptions.tooltip ~= nil then tab:SetTooltip(tabOptions.tooltip) end
	tab.Button.Activated:Connect(function() tab:SetActive(true) end)
	table.insert(self._tabs, tab)
	if tab._visible and (tabOptions.active == true or (tabOptions.active ~= false and not self.ActiveTab)) then
		tab:SetActive(true)
	end
	return tab
end

function Tab:_layoutColumns()
	for index, column in ipairs(self._columns) do
		column.Frame.LayoutOrder = index
	end
end

function Tab:Column(index)
	if index and self._columns[index] then return self._columns[index] end
	local columnIndex = index or (#self._columns + 1)
	while #self._columns < columnIndex do
		local nextIndex = #self._columns + 1
		local frame = create("Frame", {
			Name = "Column" .. tostring(nextIndex),
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
		}, self.Grid)
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			VerticalFlex = Enum.UIFlexAlignment.Fill,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, frame)
		local column = setmetatable({ _tab = self, _gui = self._window.Gui, Frame = frame }, Column)
		table.insert(self._columns, column)
	end
	self:_layoutColumns()
	return self._columns[columnIndex]
end

function Tab:AddColumn(index)
	return self:Column(index)
end

function Tab:AddSection(title, columnIndex)
	if type(title) == "table" then title = title.name or title.title end
	local column = self._columns[columnIndex or 1] or self._columns[1]
	if not column then column = self:Column() end
	return column:AddSection(title)
end

function Tab:SetActive(active)
	if active == false then
		self.Page.Visible = false
		if self._window.ActiveTab == self then self._window.ActiveTab = nil end
		if self._updateStyle then self:_updateStyle(false) end
		return
	end
	if not self._visible then return end
	local changed = self._window.ActiveTab ~= self
	for _, tab in ipairs(self._window._tabs) do
		local selected = tab == self
		tab.Page.Visible = selected and tab._visible
		tab:_updateStyle(selected)
	end
	self._window.ActiveTab = self
	if changed then invoke(self.Options.callback, self, self._window) end
end

local function createSectionContent(window, section, scrollParent, scrollPosition, scrollSize, bottomPadding)
	section.Scroll = create("ScrollingFrame", {
		Name = "ContentScroll",
		Position = scrollPosition,
		Size = scrollSize,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = window.Theme.accent,
		MidImage = window.Images.scroll,
		TopImage = window.Images.scroll,
		BottomImage = window.Images.scroll,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = true,
	}, scrollParent)
	section.Content = create("Frame", {
		Name = "Controls",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, section.Scroll)
	create("UIListLayout", {
		Padding = UDim.new(0, 4),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, section.Content)
	create("UIPadding", { PaddingBottom = UDim.new(0, bottomPadding or 10) }, section.Scroll)
	return section.Scroll
end

local function createSectionFade(window, surface)
	local fade = create("Frame", {
		Name = "BottomFade",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 60),
		BackgroundColor3 = window.Theme.high_contrast,
		BorderSizePixel = 0,
		ZIndex = 10,
	}, surface)
	create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(window.Theme.high_contrast, window.Theme.low_contrast),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(1, 0),
		}),
	}, fade)
	return fade
end

createSection = function(window, parent, title, objectName, fixedHeight)
	local section = setmetatable({
		_window = window,
		Gui = window.Gui,
		Name = title or "Section",
		_controlCount = 0,
	}, Section)
	section.Frame = create("Frame", {
		Name = objectName or "Section",
		Size = fixedHeight and UDim2.new(1, 0, 0, fixedHeight) or UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = window.Theme.inline,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, parent)
	section.Outline = create("Frame", {
		Name = "Outline",
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = window.Theme.outline,
		BorderSizePixel = 0,
	}, section.Frame)
	section.Surface = create("Frame", {
		Name = "Surface",
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = window.Theme.contrastTop,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, section.Outline)
	gradient(section.Surface, window.Theme.contrastTop, window.Theme.contrastBottom)
	section.AccentBar = create("Frame", {
		Name = "AccentBar",
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = window.Theme.accent,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, section.Surface)
	create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(167, 167, 167)),
	}, section.AccentBar)
	section.Title = label(section.Surface, section.Name, window.Theme, {
		name = "SectionTitle",
		position = UDim2.fromOffset(6, 4),
		size = UDim2.new(0, 0, 0, 0),
		automaticSize = Enum.AutomaticSize.XY,
		textSize = 12,
		color = window.Theme.text,
	})
	create("UIStroke", { LineJoinMode = Enum.LineJoinMode.Miter }, section.Title)
	createSectionContent(window, section, section.Surface,
		UDim2.fromOffset(0, 20), UDim2.new(1, 0, 1, -20))
	section.BottomFade = createSectionFade(window, section.Surface)
	return section
end

function Column:AddSection(title)
	if type(title) == "table" then title = title.name or title.title end
	local window = self._window or self._tab._window
	self._sectionCount = (self._sectionCount or 0) + 1
	local section = createSection(window, self.Frame, title, "Section_" .. tostring(self._sectionCount))
	section.Gui = self._gui or window.Gui
	return section
end

function Column:Column()
	local frame = create("Frame", {
		Name = "NestedColumn",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
	}, self.Frame)
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		VerticalFlex = Enum.UIFlexAlignment.Fill,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, frame)
	return setmetatable({ _window = self._window or self._tab._window, _gui = self._gui, Frame = frame, _sectionCount = 0 }, Column)
end

function Column:MultiSection(options)
	if type(options) == "string" then options = { names = { options } } end
	options = options or {}
	local names = options.names or { "Section A", "Section B" }
	local window = self._window or self._tab._window
	local multi = setmetatable({ _window = window, _gui = self._gui or window.Gui, Name = options.name or "MultiSection", Sections = {}, Tabs = {} }, MultiSection)
	local frame = create("Frame", {
		Name = "MultiSection",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = window.Theme.inline,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, self.Frame)
	multi.Frame = frame
	local outline = create("Frame", {
		Name = "Outline",
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = window.Theme.outline,
		BorderSizePixel = 0,
	}, frame)
	local surface = create("Frame", {
		Name = "Surface",
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = window.Theme.contrastTop,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, outline)
	gradient(surface, window.Theme.contrastTop, window.Theme.contrastBottom)
	local accent = create("Frame", {
		Name = "AccentBar",
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = window.Theme.accent,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, surface)
	create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(167, 167, 167)),
	}, accent)
	local tabHolder = create("Frame", {
		Name = "Subtabs",
		Position = UDim2.new(0, -1, 0, 0),
		Size = UDim2.new(1, 2, 0, 21),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, surface)
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalFlex = Enum.UIFlexAlignment.Fill,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, -3),
	}, tabHolder)
	multi.Pages = surface
	for index, name in ipairs(names) do
		local tabButton = create("TextButton", {
			Name = "Subtab_" .. tostring(index),
			AutoButtonColor = false,
			Size = UDim2.new(0, 0, 1, 0),
			BackgroundColor3 = window.Theme.outline,
			BorderSizePixel = 0,
			Text = "",
			ZIndex = 1,
		}, tabHolder)
		local tabInline = create("Frame", {
			Position = UDim2.fromOffset(1, 1),
			Size = UDim2.new(1, 0, 1, -2),
			BackgroundColor3 = window.Theme.inline,
			BorderSizePixel = 0,
		}, tabButton)
		local tabFace = create("Frame", {
			Position = UDim2.fromOffset(1, 1),
			Size = UDim2.new(1, 0, 1, -2),
			BackgroundColor3 = window.Theme.contrastTop,
			BorderSizePixel = 0,
		}, tabInline)
		local tabGradient = gradient(tabFace, window.Theme.contrastTop, window.Theme.contrastBottom)
		local tabLabel = label(tabFace, name, window.Theme, {
			name = "SubtabLabel",
			textSize = 12,
			align = Enum.TextXAlignment.Center,
			color = window.Theme.text,
		})
		create("UIStroke", { LineJoinMode = Enum.LineJoinMode.Miter }, tabLabel)
		window._sectionIndex = (window._sectionIndex or 0) + 1
		local section = setmetatable({
			_window = window,
			Gui = self._gui or window.Gui,
			Name = name,
			_controlCount = 0,
			Frame = frame,
			Outline = outline,
			Surface = surface,
		}, Section)
		section.Scroll = createSectionContent(window, section, surface,
			UDim2.fromOffset(0, 24), UDim2.new(1, 0, 1, -20), 60)
		section.MultiSection = multi
		section.Page = section.Scroll
		section.TabButton = tabButton
		tabButton.Activated:Connect(function() multi:SetActive(section) end)
		table.insert(multi.Sections, section)
		table.insert(multi.Tabs, { button = tabButton, label = tabLabel, face = tabFace, gradient = tabGradient })
	end
	multi.BottomFade = createSectionFade(window, surface)
	function multi:SetActive(sectionOrName)
		local selected
		for index, section in ipairs(self.Sections) do
			local active = section == sectionOrName or section.Name == sectionOrName or (sectionOrName == nil and index == 1)
			section.Scroll.Visible = active
			self.Tabs[index].label.TextColor3 = active and window.Theme.accent or window.Theme.text
			self.Tabs[index].button.Size = UDim2.new(0, 0, 1, active and 1 or 0)
			self.Tabs[index].gradient.Rotation = active and -90 or 90
			if active then selected = section end
		end
		return selected
	end
	multi:SetActive()
	return table.unpack(multi.Sections)
end

function Tab:Section(title, columnIndex) return self:AddSection(title, columnIndex) end
function Column:Section(title) return self:AddSection(title) end

function Section:_row(name, height, fullWidth)
	self._controlCount = self._controlCount + 1
	local row = create("Frame", {
		Name = "Row" .. tostring(self._controlCount),
		Size = UDim2.new(1, -8, 0, height or 14),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, self.Content)
	local nameHolder = create("Frame", {
		Name = "NameAndToggle",
		Size = UDim2.new(0, 0, 0, 14),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, row)
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 5),
	}, nameHolder)
	local text = label(nameHolder, name or "", self._window.Theme, {
		name = "Name",
		size = UDim2.new(0, 0, 0, 14),
		automaticSize = Enum.AutomaticSize.X,
		textSize = 12,
		truncate = not fullWidth,
	})
	create("UIStroke", { LineJoinMode = Enum.LineJoinMode.Miter }, text)
	local right = create("Frame", {
		Name = "Accessories",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -1, 0, 1),
		Size = UDim2.new(0, 0, 0, 12),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, row)
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, right)
	return row, text, right, nameHolder
end

local function makeControl(section, options, row, initial, setter)
	local control = { _section = section, _row = row }
	return section._window:_registerControl(control, options, initial, setter)
end

function Section:Toggle(options)
	options = options or {}
	local row, text, right, nameHolder = self:_row(options.name, 14)
	local box = create("TextButton", {
		Name = "Checkbox",
		AutoButtonColor = false,
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = self._window.Theme.outline,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		Text = "",
	}, nameHolder)
	local inner = create("Frame", {
		Name = "Inline",
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = self._window.Theme.inline,
		BorderSizePixel = 0,
	}, box)
	local face = create("Frame", {
		Name = "CheckFill",
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = self._window.Theme.accent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, inner)
	create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(117, 117, 117)),
	}, face)
	local control
	local function set(value, silent)
		value = value == true
		control.Value = value
		self._window._values[control.Flag] = value
		TweenService:Create(face, TweenInfo.new(0.12), { BackgroundTransparency = value and 0 or 1 }):Play()
		if not silent then invoke(control.Callback, value) end
		return value
	end
	control = makeControl(self, options, row, options.default == true, set)
	box.Activated:Connect(function() control:Set(not control.Value) end)
	control:Set(control.Value, true)
	control.Label = text
	control._right = right
	control.Checkbox = box
	control.Keybind = function(target, bindOptions) return target._section:_keybind(bindOptions, target._right) end
	control.Colorpicker = function(target, pickerOptions) return target._section:_colorpicker(pickerOptions, target._right) end
	control.keybind = control.Keybind
	control.colorpicker = control.Colorpicker
	return control
end

function Section:Splitter(options)
	options = options or {}
	local offset = tonumber(options.offset) or 0
	local holder = create("Frame", {
		Name = "Splitter",
		Size = UDim2.new(1, -8, 0, 8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, self.Content)
	local outline = create("Frame", {
		Name = "Outline",
		Position = UDim2.new(0, -1 + offset, 0, 3),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = self._window.Theme.outline,
		BorderSizePixel = 0,
	}, holder)
	local inline = create("Frame", {
		Name = "Inline",
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = self._window.Theme.inline,
		BorderSizePixel = 0,
	}, outline)
	create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(167, 167, 167)),
	}, inline)
	return { Frame = holder, Holder = holder, Outline = outline, Inline = inline, Offset = offset }
end

function Section:Slider(options)
	options = options or {}
	local row, text, right = self:_row(options.name, options.height or 29)
	local track = create("TextButton", {
		Name = "Track",
		AutoButtonColor = false,
		Position = UDim2.fromOffset(0, 15),
		Size = UDim2.new(1, -1, 0, 12),
		BackgroundColor3 = self._window.Theme.outline,
		BorderSizePixel = 0,
		Text = "",
	}, row)
	local inner = create("Frame", {
		Name = "Inline",
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = self._window.Theme.inline,
		BorderSizePixel = 0,
	}, track)
	local face = create("Frame", {
		Name = "Face",
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = self._window.Theme.contrastTop,
		BorderSizePixel = 0,
	}, inner)
	gradient(face, self._window.Theme.contrastTop, self._window.Theme.contrastBottom)
	local fill = create("Frame", {
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = self._window.Theme.accent,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, face)
	create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(117, 117, 117)),
	}, fill)
	local valueText = label(face, "", self._window.Theme, {
		position = UDim2.new(0, 0, 0, -1),
		size = UDim2.new(1, 0, 1, 0),
		align = Enum.TextXAlignment.Center,
		textSize = 12,
		color = self._window.Theme.text,
		zIndex = 3,
	})
	local min = tonumber(options.min or options.minimum) or 0
	local max = tonumber(options.max or options.maximum) or 100
	if max < min then min, max = max, min end
	local step = math.abs(tonumber(options.step or options.interval) or 1)
	if step == 0 then step = 1 end
	local control
	local function formatValue(value)
		if options.format then return tostring(options.format(value)) end
		local result = tostring(value)
		if result:match("%.") then result = result:gsub("0+$", ""):gsub("%.$", "") end
		return result .. (options.suffix or "")
	end
	local function set(value, silent)
		value = math.clamp(tonumber(value) or min, min, max)
		value = min + math.floor(((value - min) / step) + 0.5) * step
		local decimals = tostring(step):match("%.(%d+)")
		if decimals then value = tonumber(string.format("%." .. tostring(#decimals) .. "f", value)) end
		control.Value = value
		self._window._values[control.Flag] = value
		local ratio = max == min and 0 or math.clamp((value - min) / (max - min), 0, 1)
		fill.Size = UDim2.new(ratio, 0, 1, 0)
		valueText.Text = formatValue(value) .. "/" .. formatValue(max)
		if not silent then invoke(control.Callback, value) end
		return value
	end
	control = makeControl(self, options, row, tonumber(options.default) or min, set)
	local function updateFromPointer(x)
		local ratio = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		control:Set(min + (max - min) * ratio)
	end
	connect(self._window, track.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			updateFromPointer(input.Position.X)
			local connection
			connection = UserInputService.InputChanged:Connect(function(change)
				if change.UserInputType == Enum.UserInputType.MouseMovement or change.UserInputType == Enum.UserInputType.Touch then updateFromPointer(change.Position.X) end
			end)
			local ended
			ended = UserInputService.InputEnded:Connect(function(finish)
				if finish.UserInputType == Enum.UserInputType.MouseButton1 or finish.UserInputType == Enum.UserInputType.Touch then
					connection:Disconnect()
					ended:Disconnect()
				end
			end)
			table.insert(self._window._connections, connection)
			table.insert(self._window._connections, ended)
		end
	end)
	control:Set(control.Value, true)
	control.Label = text
	control._right = right
	control.Track = track
	return control
end

function Section:Dropdown(options)
	options = options or {}
	local row, text, right = self:_row(options.name, options.height or 33)
	local open = button(row, "Select", self._window.Theme, {
		name = "DropdownButton",
		position = UDim2.fromOffset(0, 15),
		size = UDim2.new(1, -1, 0, 18),
		textSize = 12,
		align = Enum.TextXAlignment.Left,
		background = self._window.Theme.outline,
		border = self._window.Theme.inline,
		radius = 0,
	})
	create("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, open)
	label(open, "+", self._window.Theme, {
		name = "Expand",
		position = UDim2.new(1, -12, 0, 0),
		size = UDim2.fromOffset(9, 18),
		align = Enum.TextXAlignment.Right,
		textSize = 12,
		zIndex = 4,
	})
	local items = options.items or options.options or {}
	local multi = options.multi == true or options.multiselect == true
	local control
	local function display(value)
		if multi then
			local selected = {}
			for _, item in ipairs(value or {}) do table.insert(selected, tostring(item)) end
			open.Text = #selected == 0 and "Select" or table.concat(selected, ", ")
		else
			open.Text = value == nil and "Select" or tostring(value)
		end
	end
	local function set(value, silent)
		if multi then
			local list = {}
			if type(value) == "table" then for _, item in ipairs(value) do table.insert(list, item) end end
			value = list
		end
		control.Value = value
		self._window._values[control.Flag] = copyValue(value)
		display(value)
		if not silent then invoke(control.Callback, copyValue(value)) end
		return value
	end
	local default = options.default
	if multi and type(default) ~= "table" then default = {} end
	control = makeControl(self, options, row, default, set)
	local function openList()
		local rowHeight = 23
		local listHeight = math.min(#items * rowHeight + (multi and 28 or 0) + 10, options.maxHeight or 220)
		local popup = self._window:_openPopup(open, options.popupWidth or 220, math.max(48, listHeight), function(frame)
			local list = create("ScrollingFrame", {
				Position = UDim2.fromOffset(5, 5),
				Size = UDim2.new(1, -10, 1, multi and -34 or -10),
				CanvasSize = UDim2.new(0, 0, 0, #items * rowHeight),
				ScrollBarThickness = 3,
				ScrollBarImageColor3 = self._window.Theme.accent,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 91,
			}, frame)
			create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, list)
			for index, item in ipairs(items) do
				local itemValue = type(item) == "table" and (item.value or item.name or item[1]) or item
				local current = control.Value
				local selected = false
				if multi then
					for _, picked in ipairs(current or {}) do if picked == itemValue then selected = true break end end
				else
					selected = current == itemValue
				end
				local optionButton = button(list, (selected and "✓  " or "     ") .. tostring(type(item) == "table" and (item.label or item.name or item[1]) or item), self._window.Theme, {
					name = "Option",
					size = UDim2.new(1, -4, 0, rowHeight),
					textSize = 10,
					align = Enum.TextXAlignment.Left,
					background = selected and self._window.Theme.surfaceHover or self._window.Theme.surface,
					zIndex = 92,
				})
				optionButton.LayoutOrder = index
				optionButton.Activated:Connect(function()
					if multi then
						local nextValue, found = {}, false
						for _, picked in ipairs(control.Value or {}) do
							if picked == itemValue then found = true else table.insert(nextValue, picked) end
						end
						if not found then table.insert(nextValue, itemValue) end
						control:Set(nextValue)
						openList()
					else
						control:Set(itemValue)
						self._window:_closePopup()
					end
				end)
			end
			if multi then
				local done = button(frame, "Done", self._window.Theme, {
					position = UDim2.new(0, 5, 1, -27),
					size = UDim2.new(1, -10, 0, 22),
					background = self._window.Theme.accent,
					border = self._window.Theme.accent,
					zIndex = 92,
				})
				done.Activated:Connect(function() self._window:_closePopup() end)
			end
		end)
		return popup
	end
	open.Activated:Connect(openList)
	control:Set(control.Value, true)
	control.Label = text
	control._right = right
	control.SetItems = function(target, nextItems)
		items = nextItems or {}
		target:Set(multi and {} or nil, true)
	end
	return control
end

function Section:Textbox(options)
	options = options or {}
	local hasName = type(options.name) == "string" and options.name ~= ""
	local row, text = self:_row(options.name, options.height or (hasName and 33 or 18))
	local input = create("TextBox", {
		Name = "Input",
		Position = UDim2.fromOffset(0, hasName and 15 or 0),
		Size = UDim2.new(1, -1, 0, 18),
		BackgroundColor3 = self._window.Theme.outline,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = Enum.Font.Legacy,
		Text = tostring(options.default or ""),
		PlaceholderText = options.placeholder or "Type here...",
		PlaceholderColor3 = self._window.Theme.muted,
		TextColor3 = self._window.Theme.text,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	stroke(input, self._window.Theme.inline, 1)
	create("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, input)
	local control
	local function set(value, silent)
		value = tostring(value == nil and "" or value)
		if options.max then value = string.sub(value, 1, options.max) end
		control.Value = value
		self._window._values[control.Flag] = value
		input.Text = value
		if not silent then invoke(control.Callback, value) end
		return value
	end
	control = makeControl(self, options, row, tostring(options.default or ""), set)
	input.FocusLost:Connect(function(enterPressed)
		if options.enterOnly and not enterPressed then return end
		control:Set(input.Text)
	end)
	control:Set(control.Value, true)
	control.Input = input
	control.Label = text
	control._right = nil
	return control
end

function Section:Button(options)
	options = options or {}
	local name = tostring(options.text or options.name or "Button")
	local callback = options.callback
	local style = {}
	for key, value in pairs(options.style or {}) do style[key] = value end
	for key, value in pairs(options) do
		if style[key] == nil then style[key] = value end
	end
	local row, click
	local holder = self._buttonHolder
	if holder and holder.Parent == self.Content then
		row = holder
		style.position = style.position or UDim2.fromOffset(0, 2)
		style.size = style.size or UDim2.new(1, -27, 0, 18)
		style.textSize = style.textSize or 12
		click = sourceActionButton(holder, name, self._window.Theme, style)
	else
		local text
		row, text = self:_row(options.name or name, options.height or 28, true)
		style.position = style.position or UDim2.fromOffset(2, 2)
		style.size = style.size or UDim2.new(1, -4, 1, -4)
		style.textSize = style.textSize or 12
		click = sourceActionButton(row, name, self._window.Theme, style)
		text.Visible = false
	end
	local control = { _section = self, _row = row, Name = name, Flag = options.flag, _buttonHolder = holder }
	control.Button = click
	local title = click:FindFirstChild("Title", true)
	local confirmUntil = 0
	local confirmToken = 0
	local function restoreTitle()
		control._confirming = false
		confirmUntil = 0
		title.Text = name
	end
	control.Activate = function()
		if options.confirm then
			if not control._confirming then
				control._confirming = true
				confirmToken = confirmToken + 1
				local token = confirmToken
				local duration = math.max(1, options.confirmTime or 3)
				confirmUntil = os.clock() + duration
				title.Text = options.confirmText or ("Confirm " .. name .. "? (" .. duration .. "s)")
				task.spawn(function()
					while click.Parent and control._confirming and token == confirmToken do
						local remaining = math.ceil(confirmUntil - os.clock())
						if remaining <= 0 then
							restoreTitle()
							break
						end
						if not options.confirmText then
							title.Text = "Confirm " .. name .. "? (" .. remaining .. "s)"
						end
						task.wait(0.1)
					end
				end)
				return
			end
		end
		confirmToken = confirmToken + 1
		restoreTitle()
		invoke(callback, control, self)
	end
	click.Activated:Connect(control.Activate)
	local tooltipText = options.tooltip
	local closeTooltip
	local function setTooltip(text)
		if closeTooltip then closeTooltip(); closeTooltip = nil end
		tooltipText = text
		if text and text ~= "" then closeTooltip = self._window:AddTooltip(holder and click or row, tostring(text)) end
	end
	function control:SetText(text)
		name = tostring(text or "")
		self.Name = name
		restoreTitle()
		return name
	end
	function control:SetCallback(nextCallback)
		callback = nextCallback
	end
	function control:SetVisible(visible)
		if self._buttonHolder then click.Visible = visible ~= false
		else row.Visible = visible ~= false end
	end
	function control:SetTooltip(text)
		setTooltip(text)
	end
	function control:SetStyle(nextStyle)
		nextStyle = nextStyle or {}
		for key, value in pairs(nextStyle) do style[key] = value end
		local inline = click:FindFirstChild("Inline")
		local accent = inline and inline:FindFirstChild("Accent")
		local face = accent and accent:FindFirstChild("Face")
		local hoverFill = accent and accent:FindFirstChild("HoverFill")
		if style.buttonColor or style.backgroundColor then click.BackgroundColor3 = style.buttonColor or style.backgroundColor end
		if style.inlineColor and inline then inline.BackgroundColor3 = style.inlineColor end
		if style.accentColor and accent then accent.BackgroundColor3 = style.accentColor end
		if style.accentPosition and accent then accent.Position = style.accentPosition end
		if style.accentSize and accent then accent.Size = style.accentSize end
		if style.surfaceColor and face then face.BackgroundColor3 = style.surfaceColor end
		if style.hoverColor and hoverFill then hoverFill.BackgroundColor3 = style.hoverColor end
		if style.textColor then title.TextColor3 = style.textColor end
		if style.textSize then title.TextSize = style.textSize end
		if style.fontFace then title.FontFace = style.fontFace elseif style.font then title.Font = style.font end
		if style.position then click.Position = style.position end
		if style.size then click.Size = style.size end
		if style.zIndex then click.ZIndex = style.zIndex end
		if style.autoButtonColor ~= nil then click.AutoButtonColor = style.autoButtonColor end
		if style.textStrokeColor then title.TextStrokeColor3 = style.textStrokeColor end
		if style.textStrokeTransparency then title.TextStrokeTransparency = style.textStrokeTransparency end
		if style.textTransparency then title.TextTransparency = style.textTransparency end
		if style.align then title.TextXAlignment = style.align end
		if style.labelPosition then title.Position = style.labelPosition end
		if style.labelSize then title.Size = style.labelSize end
		if style.inlinePosition and inline then inline.Position = style.inlinePosition end
		if style.inlineSize and inline then inline.Size = style.inlineSize end
		if style.surfacePosition and face then face.Position = style.surfacePosition end
		if style.surfaceSize and face then face.Size = style.surfaceSize end
		if style.accentTopColor or style.accentBottomColor then
			local accentGradient = accent and accent:FindFirstChildOfClass("UIGradient")
			if accentGradient then
				accentGradient.Color = ColorSequence.new(style.accentTopColor or Color3.fromRGB(255, 255, 255), style.accentBottomColor or Color3.fromRGB(167, 167, 167))
			end
		end
		if style.surfaceColor or style.surfaceBottomColor then
			local surfaceGradient = face and face:FindFirstChildOfClass("UIGradient")
			if surfaceGradient then
				surfaceGradient.Color = ColorSequence.new(style.surfaceColor or self._section._window.Theme.contrastTop, style.surfaceBottomColor or self._section._window.Theme.contrastBottom)
			end
		end
		if style.height and not self._buttonHolder then
			row.Size = UDim2.new(row.Size.X.Scale, row.Size.X.Offset, 0, style.height)
		end
	end
	function control:Destroy()
		if closeTooltip then closeTooltip(); closeTooltip = nil end
		if self._buttonHolder and click.Parent then click:Destroy()
		elseif row.Parent then row:Destroy() end
	end
	if tooltipText then setTooltip(tooltipText) end
	return control
end

function Section:Label(options)
	if type(options) == "string" then options = { name = options } end
	options = options or {}
	local row, text, right = self:_row(options.name or options.text or "", options.height or 14)
	text.TextSize = options.textSize or 12
	text.TextColor3 = options.color or self._window.Theme.text
	text.TextWrapped = options.wrapped == true
	local control = { _section = self, _row = row, _right = right, Label = text, Value = text.Text }
	if options.tooltip then self._window:AddTooltip(row, options.tooltip) end
	control.Set = function(target, value)
		target.Value = tostring(value or "")
		text.Text = target.Value
	end
	control.SetVisible = function(_, visible) row.Visible = visible ~= false end
	control.Keybind = function(target, bindOptions) return target._section:_keybind(bindOptions, target._right, target) end
	control.Colorpicker = function(target, pickerOptions) return target._section:_colorpicker(pickerOptions, target._right, target) end
	control.keybind = control.Keybind
	control.colorpicker = control.Colorpicker
	return control
end

function Section:Divider()
	local row = create("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = self._window.Theme.border, BorderSizePixel = 0 }, self.Content)
	return { Object = row, SetVisible = function(_, visible) row.Visible = visible ~= false end }
end

function Section:MultiButton(options)
	options = options or {}
	local row, text, right = self:_row(options.name or "Actions", options.height or 28)
	local callbacks = options.buttons or options.items or {}
	for index, item in ipairs(callbacks) do
		local name = type(item) == "table" and (item.name or item.text or item[1]) or tostring(item)
		local callback = type(item) == "table" and item.callback or nil
		local itemButton = button(right, name, self._window.Theme, { size = UDim2.new(1 / #callbacks, -2, 0, 22), textSize = 9 })
		itemButton.LayoutOrder = index
		itemButton.Activated:Connect(function() invoke(callback) end)
	end
	return { _row = row, Label = text, _right = right }
end

function Section:_keybind(options, right, owner)
	options = options or {}
	if not right then
		local row, text
		row, text, right = self:_row(options.name or "Keybind", 14)
		owner = owner or { _section = self, _row = row, Label = text }
	end
	local window = self._window
	local ownerRow = owner and owner._row
	local key = options.key
	local mode = normalizeMode(options.mode)
	local active = mode == "Always" or (mode ~= "Never" and options.default == true)
	local bindButton = button(right, "None", window.Theme, {
		size = UDim2.fromOffset(42, 14), textSize = 10,
		background = window.Theme.outline, border = window.Theme.inline,
	})
	local modeButton = button(right, mode, window.Theme, {
		size = UDim2.fromOffset(38, 14), textSize = 9,
		background = window.Theme.outline, border = window.Theme.inline,
	})
	local control = {}
	control._section = self
	control._row = ownerRow or (right and right.Parent)
	control.Name = options.name or control.Name or "Keybind"
	control.Flag = options.flag or normalizeFlag(control.Name, #window._controls + #window._keybinds + 1)
	control.key = key
	control.mode = mode
	control.active = active
	control._capturing = false
	control.Callback = options.callback
	control._window = window
	local function render()
		bindButton.Text = control._capturing and "Press key" or keyName(control.key)
		modeButton.Text = control.mode
	end
	function control:Set(value, silent)
		if type(value) == "table" then
			control.key = value.key
			control.mode = normalizeMode(value.mode or control.mode)
			control.active = value.active == true
		else
			control.key = value
		end
		if control.mode == "Always" then control.active = true elseif control.mode == "Never" then control.active = false end
		window._values[control.Flag] = { key = control.key, mode = control.mode, active = control.active }
		render()
		if window._keybindList then window._keybindList:Refresh() end
		if not silent then invoke(control.Callback, control.active, control.key, control.mode) end
		return control.key
	end
	function control:Get()
		return { key = control.key, mode = control.mode, active = control.active }
	end
	function control:SetActive(value, silent)
		control.active = control.mode == "Always" or (control.mode ~= "Never" and value == true)
		window._values[control.Flag] = { key = control.key, mode = control.mode, active = control.active }
		if window._keybindList then window._keybindList:Refresh() end
		if not silent then invoke(control.Callback, control.active, control.key, control.mode) end
		return control.active
	end
	function control:SetVisible(visible)
		if control._row then control._row.Visible = visible ~= false end
	end
	window._flags[control.Flag] = control
	window._values[control.Flag] = control:Get()
	table.insert(window._controls, control)
	if options.tooltip and control._row then window:AddTooltip(control._row, options.tooltip) end
	bindButton.Activated:Connect(function()
		control._capturing = true
		render()
		window:_closePopup()
	end)
	modeButton.Activated:Connect(function()
		local modes = { "Toggle", "Hold", "Always", "Never" }
		local current = table.find(modes, control.mode) or 1
		control.mode = modes[current % #modes + 1]
		if control.mode == "Always" then control:SetActive(true) elseif control.mode == "Never" then control:SetActive(false) end
		control:Set(control:Get())
	end)
	table.insert(window._keybinds, control)
	render()
	if window._keybindList then window._keybindList:Refresh() end
	control._right = right
	control.Button = bindButton
	return control
end

function Section:Keybind(options)
	return self:_keybind(options)
end

function Section:_colorpicker(options, right, owner)
	options = options or {}
	local row, text
	if not right then
		row, text, right = self:_row(options.name or "Color", 14)
		owner = owner or { _section = self, _row = row, Label = text }
	end
	local window = self._window
	local ownerRow = owner and owner._row
	local initialColor = options.color or options.default or Color3.new(1, 1, 1)
	local initialAlpha = options.alpha or 1
	local control = {}
	control._section = self
	control._row = ownerRow or (right and right.Parent)
	control.Name = options.name or control.Name or "Color"
	control.Flag = options.flag or normalizeFlag(control.Name, #window._controls + 1)
	control.Callback = options.callback
	control.Value = { color = initialColor, alpha = initialAlpha }
	control.Alpha = initialAlpha
	control._window = window
	local swatch = button(right, "", window.Theme, {
		size = UDim2.fromOffset(14, 14),
		background = initialColor,
		border = window.Theme.inline,
		textSize = 8,
	})
	swatch.BackgroundTransparency = 1 - initialAlpha
	swatch.TextColor3 = initialColor
	local function set(value, alpha, silent)
		local color = value
		if type(value) == "table" then
			color = value.color or value[1] or initialColor
			alpha = value.alpha or value[2] or alpha
		end
		if typeof(color) ~= "Color3" then return control.Value end
		alpha = math.clamp(tonumber(alpha) or control.Alpha or 1, 0, 1)
		control.Value = { color = color, alpha = alpha }
		control.Alpha = alpha
		window._values[control.Flag] = { color = color, alpha = alpha }
		swatch.BackgroundColor3 = color
		swatch.BackgroundTransparency = 1 - alpha
		swatch.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.5)
		if not silent then invoke(control.Callback, color, alpha) end
		return control.Value
	end
	control.Set = function(_, value, alpha, silent)
		if type(alpha) == "boolean" and silent == nil then silent, alpha = alpha, nil end
		return set(value, alpha, silent)
	end
	control.Get = function() return control.Value end
	control.SetVisible = function(_, visible) if control._row then control._row.Visible = visible ~= false end end
	window._flags[control.Flag] = control
	window._values[control.Flag] = copyValue(control.Value)
	table.insert(window._controls, control)
	if options.tooltip and control._row then window:AddTooltip(control._row, options.tooltip) end
	swatch.Activated:Connect(function()
		local hue, saturation, brightness = control.Value.color:ToHSV()
		local popupWidth, popupHeight = 224, 184
		window:_openPopup(swatch, popupWidth, popupHeight, function(frame)
			local square = create("TextButton", {
				Name = "SaturationValue",
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.fromOffset(164, 120),
				BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
				Text = "",
				AutoButtonColor = false,
				BorderSizePixel = 0,
				ZIndex = 91,
			}, frame)
			local white = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 92 }, square)
			create("UIGradient", {
				Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHSV(hue, 1, 1)),
				Rotation = 0,
			}, white)
			local shade = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 93 }, square)
			create("UIGradient", {
				Color = ColorSequence.new(Color3.new(0, 0, 0), Color3.new(0, 0, 0)),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }),
				Rotation = 90,
			}, shade)
			local cursor = create("Frame", {
				Name = "Cursor",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(saturation, 1 - brightness),
				Size = UDim2.fromOffset(8, 8),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 94,
			}, square)
			corner(cursor, 5)
			stroke(cursor, Color3.new(1, 1, 1), 1)
			local squareInput = create("TextButton", {
				Name = "ColorInput",
				Position = UDim2.fromScale(0, 0),
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Text = "",
				AutoButtonColor = false,
				ZIndex = 95,
			}, square)
			local hueBar = create("TextButton", {
				Name = "Hue",
				Position = UDim2.fromOffset(179, 8),
				Size = UDim2.fromOffset(16, 120),
				Text = "",
				AutoButtonColor = false,
				BorderSizePixel = 0,
				BackgroundColor3 = Color3.new(1, 1, 1),
				ZIndex = 91,
			}, frame)
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
			local marker = create("Frame", {
				Name = "HueMarker",
				Position = UDim2.new(0, -2, hue, -1),
				Size = UDim2.new(1, 4, 0, 3),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
			}, hueBar)
			local hex = create("TextBox", {
				Name = "Hex",
				Position = UDim2.fromOffset(8, 137),
				Size = UDim2.fromOffset(120, 25),
				BackgroundColor3 = window.Theme.background,
				BorderSizePixel = 0,
				ClearTextOnFocus = false,
				Font = Enum.Font.Code,
				Text = "#" .. control.Value.color:ToHex(),
				TextColor3 = window.Theme.text,
				PlaceholderText = "#RRGGBB",
				TextSize = 10,
				ZIndex = 91,
			}, frame)
			corner(hex, 2)
			stroke(hex, window.Theme.border, 1)
			label(frame, "Opacity", window.Theme, { position = UDim2.fromOffset(134, 137), size = UDim2.fromOffset(45, 25), textSize = 9, color = window.Theme.muted, zIndex = 91 })
			local alphaValue = label(frame, tostring(math.floor(control.Alpha * 100)) .. "%", window.Theme, { position = UDim2.fromOffset(180, 137), size = UDim2.fromOffset(34, 25), textSize = 9, align = Enum.TextXAlignment.Right, zIndex = 91 })
			local function applyHSV()
				local color = Color3.fromHSV(hue, saturation, brightness)
				set(color, control.Alpha)
				white:FindFirstChildOfClass("UIGradient").Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHSV(hue, 1, 1))
				cursor.Position = UDim2.fromScale(saturation, 1 - brightness)
				marker.Position = UDim2.new(0, -2, hue, -1)
				hex.Text = "#" .. color:ToHex()
			end
			local function getPointerPosition(input)
				local gui = frame:FindFirstAncestorOfClass("ScreenGui")
				if input.UserInputType ~= Enum.UserInputType.Touch then
					local pointer = window.Pointer
					if pointer and pointer.Parent then
						return pointer.AbsolutePosition
					end
				end
				local position = Vector2.new(input.Position.X, input.Position.Y)
				if gui and gui.IgnoreGuiInset then
					local topLeftInset = GuiService:GetGuiInset()
					position += topLeftInset
				end
				return position
			end
			local function updateSquare(input)
				local position = getPointerPosition(input)
				saturation = math.clamp((position.X - square.AbsolutePosition.X) / square.AbsoluteSize.X, 0, 1)
				brightness = 1 - math.clamp((position.Y - square.AbsolutePosition.Y) / square.AbsoluteSize.Y, 0, 1)
				applyHSV()
			end
			local function updateHue(input)
				local position = getPointerPosition(input)
				hue = math.clamp((position.Y - hueBar.AbsolutePosition.Y) / hueBar.AbsoluteSize.Y, 0, 1)
				square.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
				applyHSV()
			end
			local function startDrag(target, updater)
				target.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						updater(input)
						local changeConnection = UserInputService.InputChanged:Connect(function(change)
							if change.UserInputType == Enum.UserInputType.MouseMovement or change.UserInputType == Enum.UserInputType.Touch then updater(change) end
						end)
						local endConnection
						endConnection = UserInputService.InputEnded:Connect(function(finish)
							if finish.UserInputType == Enum.UserInputType.MouseButton1 or finish.UserInputType == Enum.UserInputType.Touch then
								changeConnection:Disconnect()
								endConnection:Disconnect()
							end
						end)
						table.insert(window._connections, changeConnection)
						table.insert(window._connections, endConnection)
					end
				end)
			end
			startDrag(squareInput, updateSquare)
			startDrag(hueBar, updateHue)
			hex.FocusLost:Connect(function()
				local raw = hex.Text:gsub("#", "")
				if #raw == 6 and raw:match("^%x+$") then
					local ok, color = pcall(function() return Color3.fromHex(raw) end)
					if ok then
						hue, saturation, brightness = color:ToHSV()
						square.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
						applyHSV()
					else
						hex.Text = "#" .. control.Value.color:ToHex()
					end
				else
					hex.Text = "#" .. control.Value.color:ToHex()
				end
			end)
			local alphaSlider = create("TextButton", {
				Name = "OpacityTrack",
				Position = UDim2.fromOffset(8, 169),
				Size = UDim2.new(1, -16, 0, 4),
				BackgroundColor3 = window.Theme.border,
				BorderSizePixel = 0,
				Text = "",
				ZIndex = 91,
			}, frame)
			local alphaFill = create("Frame", {
				Name = "OpacityFill",
				Size = UDim2.new(control.Alpha, 0, 1, 0),
				BackgroundColor3 = window.Theme.accent,
				BorderSizePixel = 0,
				ZIndex = 92,
			}, alphaSlider)
			corner(alphaSlider, 3)
			corner(alphaFill, 3)
			local function updateAlpha(x)
				local alpha = math.clamp((x - alphaSlider.AbsolutePosition.X) / math.max(alphaSlider.AbsoluteSize.X, 1), 0, 1)
				set(control.Value.color, alpha)
				alphaFill.Size = UDim2.new(alpha, 0, 1, 0)
				alphaValue.Text = tostring(math.floor(alpha * 100)) .. "%"
			end
			alphaSlider.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					updateAlpha(input.Position.X)
					local changeConnection = UserInputService.InputChanged:Connect(function(change)
						if change.UserInputType == Enum.UserInputType.MouseMovement or change.UserInputType == Enum.UserInputType.Touch then updateAlpha(change.Position.X) end
					end)
					local endConnection
					endConnection = UserInputService.InputEnded:Connect(function(finish)
						if finish.UserInputType == Enum.UserInputType.MouseButton1 or finish.UserInputType == Enum.UserInputType.Touch then
							changeConnection:Disconnect()
							endConnection:Disconnect()
						end
					end)
					table.insert(window._connections, changeConnection)
					table.insert(window._connections, endConnection)
				end
			end)
		end)
	end)
	control._right = right
	control.Swatch = swatch
	control.set = control.Set
	return control
end

function Section:Colorpicker(options)
	return self:_colorpicker(options)
end

function Section:Output(options)
	options = options or {}
	local row, text = self:_row(options.name or "Output", options.height or 150, true)
	text.Visible = false
	local list = create("ScrollingFrame", {
		Name = "OutputList",
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = self._window.Theme.accent,
		BackgroundColor3 = self._window.Theme.background,
		BorderSizePixel = 0,
	}, row)
	corner(list, 2)
	create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	create("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, list)
	local output = { Frame = list, _window = self._window }
	function output:Add(message, prefix, color)
		local line = label(list, (prefix and ("[" .. tostring(prefix) .. "] ") or "") .. tostring(message), self._window.Theme, {
			size = UDim2.new(1, 0, 0, 18),
			textSize = 9,
			color = color or self._window.Theme.text,
			wrapped = true,
		})
		line.AutomaticSize = Enum.AutomaticSize.Y
		line.LayoutOrder = #list:GetChildren()
		return line
	end
	function output:Clear()
		for _, child in ipairs(list:GetChildren()) do if child:IsA("TextLabel") then child:Destroy() end end
	end
	return output
end

function Section:List(options)
	options = options or {}
	local row, text = self:_row(options.name or "List", options.height or 128, true)
	text.Visible = false
	local scrolling = create("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = self._window.Theme.accent,
		BackgroundColor3 = self._window.Theme.background,
		BorderSizePixel = 0,
	}, row)
	corner(scrolling, 2)
	create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, scrolling)
	local listControl = { Frame = scrolling, _window = self._window }
	function listControl:SetItems(items)
		for _, child in ipairs(scrolling:GetChildren()) do if child:IsA("TextButton") or child:IsA("TextLabel") then child:Destroy() end end
		for index, item in ipairs(items or {}) do
			local itemName = type(item) == "table" and (item.name or item.text or item[1]) or tostring(item)
			local itemValue = type(item) == "table" and (item.value or itemName) or item
			local entry = button(scrolling, itemName, self._window.Theme, { size = UDim2.new(1, -4, 0, 22), textSize = 9, align = Enum.TextXAlignment.Left })
			entry.LayoutOrder = index
			entry.Activated:Connect(function() invoke(options.callback, itemValue) end)
		end
	end
	listControl:SetItems(options.items or {})
	listControl.SetVisible = function(_, visible) row.Visible = visible ~= false end
	return listControl
end

function Section:ButtonHolder(options)
	options = options or {}
	local holder = create("TextLabel", {
		Name = options.name or "ButtonHolder",
		Size = UDim2.new(1, -8, 0, options.height or 12),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = options.text or "",
		TextColor3 = self._window.Theme.text,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 2,
	}, self.Content)
	create("UIStroke", { LineJoinMode = Enum.LineJoinMode.Miter }, holder)
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalFlex = Enum.UIFlexAlignment.Fill,
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, holder)
	self._buttonHolder = holder
	local buttonHolder = {
		Frame = holder,
		Name = options.name or "ButtonHolder",
		Flag = options.flag,
		SetVisible = function(_, visible) holder.Visible = visible ~= false end,
	}
	if options.buttons or options.items then
		for _, item in ipairs(options.buttons or options.items) do
			if type(item) == "table" then
				self:Button(item)
			else
				self:Button({ name = tostring(item) })
			end
		end
	end
	return buttonHolder
end

function Section:Configuration(options, builder, owner)
	if type(options) == "string" then options = { name = options } end
	options = options or {}
	if not owner then
		local row, title, right = self:_row(options.name or "Configuration", 14)
		title.Visible = false
		owner = { _section = self, _row = row, _right = right }
	end

	local window = self._window
	local theme = window.Theme
	local popupGui = owner._row:FindFirstAncestorOfClass("ScreenGui") or window.Gui
	local icon = create("TextButton", {
		Name = "ConfigurationButton",
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = theme.outline,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 3,
	}, owner._right)
	local inline = create("Frame", {
		Name = "Inline",
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = theme.inline,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, icon)
	local face = create("Frame", {
		Name = "Face",
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = theme.contrastTop,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, inline)
	gradient(face, theme.contrastTop, theme.contrastBottom)
	label(face, "#", theme, {
		name = "Icon",
		textSize = 12,
		align = Enum.TextXAlignment.Center,
		zIndex = 4,
	})

	local popup = create("Frame", {
		Name = "ConfigurationPopup",
		Size = UDim2.new(0, 220, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = theme.outline,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 90,
		ClipsDescendants = true,
	}, popupGui)
	local accent = create("Frame", {
		Name = "Accent",
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = theme.accent,
		BorderSizePixel = 0,
		ZIndex = 91,
	}, popup)
	local panel = create("Frame", {
		Name = "Surface",
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = theme.high_contrast,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 92,
	}, accent)
	gradient(panel, theme.contrastTop, theme.contrastBottom)
	local title = label(panel, options.name or "Configuration", theme, {
		name = "ConfigurationTitle",
		position = UDim2.fromOffset(7, 4),
		size = UDim2.new(1, -14, 0, 12),
		textSize = 12,
		zIndex = 93,
	})
	create("UIStroke", { LineJoinMode = Enum.LineJoinMode.Miter }, title)
	local content = create("Frame", {
		Name = "Controls",
		Position = UDim2.fromOffset(4, 20),
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 93,
	}, panel)
	create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, content)
	create("UIPadding", { PaddingBottom = UDim.new(0, 6) }, content)
	local nested = setmetatable({
		_window = window,
		Gui = popupGui,
		Name = options.name or "Configuration",
		Content = content,
		Frame = popup,
		_controlCount = 0,
	}, Section)
	if builder then invoke(builder, nested) end
	local function raisePopupLayer(parent)
		for _, child in ipairs(parent:GetChildren()) do
			if child:IsA("GuiObject") then
				child.ZIndex = parent.ZIndex + 1
				raisePopupLayer(child)
			end
		end
	end
	raisePopupLayer(popup)
	owner.ConfigurationButton = icon
	owner.Configuration = nested

	local opened = false
	local function close()
		opened = false
		if window._popup and window._popup.owner == icon then
			window:_closePopup()
		else
			popup.Visible = false
		end
	end
	local function placePopup()
		if not popup.Visible then return end
		local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1024, 768)
		local anchor = icon.AbsolutePosition
		local height = math.max(popup.AbsoluteSize.Y, 52)
		local x = math.clamp(anchor.X - 206, 6, math.max(6, viewport.X - 226))
		local y = anchor.Y + 17
		if y + height > viewport.Y - 6 then y = math.max(6, anchor.Y - height - 4) end
		popup.Position = UDim2.fromOffset(x, y)
	end
	local function open()
		window:_closePopup()
		local catcher = create("TextButton", {
			Name = "PopupCatcher",
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 80,
		}, popupGui)
		catcher.Activated:Connect(function() window:_closePopup() end)
		window._popup = {
			catcher = catcher,
			frame = popup,
			owner = icon,
			preserve = true,
			onClose = function() opened = false end,
		}
		popup.Visible = true
		opened = true
		placePopup()
		task.defer(placePopup)
	end
	icon.Activated:Connect(function()
		if opened then close() else open() end
	end)
	return nested
end

-- API aliases matching the lowercase builder style used by the source menu.
BacktrackUI.tab = BacktrackUI.AddTab
BacktrackUI.window = function(_, options)
	options = options or {}
	return BacktrackUI.new({
		name = options.gui_name,
		title = options.title or options.name,
		parent = options.parent,
		size = options.size,
		width = options.width,
		height = options.height,
		position = options.position,
		anchorPoint = options.anchor_point,
		toggleKey = options.toggle_key,
		theme = options.theme,
		images = options.images,
	})
end
BacktrackUI.panel = function(self, options)
	options = options or {}
	return self:CreatePanel(options.title or options.name, {
		name = options.gui_name,
		position = options.position,
		size = options.size,
	})
end
BacktrackUI.watermark = function(self, options)
	if type(options) == "string" then return self:CreateWatermark(options) end
	options = options or {}
	return self:CreateWatermark(options.text or options.name, options)
end
BacktrackUI.notification = function(self, options)
	if type(options) == "string" then return self:Notify(options) end
	options = options or {}
	return self:Notify(options.text or options.name or "", options.time or options.duration, options.kind)
end
BacktrackUI.tool_tip = function(self, options)
	options = options or {}
	return self:AddTooltip(options.path or options.target, options.name or options.text or "")
end
BacktrackUI.unload = BacktrackUI.Destroy
BacktrackUI.set_theme = BacktrackUI.SetTheme
BacktrackUI.create_dock = BacktrackUI.CreateDock
BacktrackUI.create_keybind_list = BacktrackUI.CreateKeybindList
BacktrackUI.add_tab = BacktrackUI.AddTab
BacktrackUI.get_tabs = BacktrackUI.GetTabs
BacktrackUI.remove_tab = BacktrackUI.RemoveTab
BacktrackUI.clear_tabs = BacktrackUI.ClearTabs
BacktrackUI.set_title = BacktrackUI.SetTitle
BacktrackUI.set_position = BacktrackUI.SetPosition
BacktrackUI.set_size = BacktrackUI.SetSize
Tab.column = Tab.AddColumn
Tab.section = Tab.AddSection
Tab.set_active = Tab.SetActive
Tab.set_visible = Tab.SetVisible
Tab.set_style = Tab.SetStyle
Tab.set_callback = Tab.SetCallback
Column.section = Column.AddSection
Column.column = Column.Column
Column.multi_section = Column.MultiSection
Column.add_multi_section = Column.MultiSection
Section.toggle = Section.Toggle
Section.splitter = Section.Splitter
Section.slider = Section.Slider
Section.dropdown = Section.Dropdown
Section.textbox = Section.Textbox
Section.button = Section.Button
Section.AddButton = Section.Button
Section.add_button = Section.Button
Section.label = Section.Label
Section.keybind = Section.Keybind
Section.colorpicker = Section.Colorpicker
Section.output = Section.Output
Section.list = Section.List
Section.button_holder = Section.ButtonHolder
Section.configuration = Section.Configuration

return BacktrackUI
