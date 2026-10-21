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

BacktrackUI.Version = "1.5.4"
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
local TweenService = getService("TweenService")
local RunService = getService("RunService")
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
		TextStrokeColor3 = theme.text_outline,
		TextStrokeTransparency = options.textStrokeTransparency or 1,
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
		AutoButtonColor = false,
		BackgroundColor3 = theme.outline,
		BorderSizePixel = 0,
		Position = options.position or UDim2.new(),
		Size = options.size or UDim2.new(1, 0, 0, 18),
		Text = "",
		ZIndex = options.zIndex or 2,
	}, parent)
	local inline = create("Frame", {
		Name = "Inline",
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = theme.inline,
		BorderSizePixel = 0,
		ZIndex = control.ZIndex + 1,
	}, control)
	local accent = create("Frame", {
		Name = "Accent",
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = theme.accent,
		BorderSizePixel = 0,
		ZIndex = control.ZIndex + 1,
	}, inline)
	gradient(accent, Color3.fromRGB(255, 255, 255), Color3.fromRGB(167, 167, 167))
	local face = create("Frame", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = theme.contrastTop,
		BorderSizePixel = 0,
		ZIndex = control.ZIndex + 1,
	}, accent)
	gradient(face, theme.contrastTop, theme.contrastBottom)
	local title = label(face, text, theme, {
		name = "Title",
		position = UDim2.new(0, 4, 0, -1),
		size = UDim2.new(1, -4, 1, 0),
		textSize = options.textSize or 12,
		align = options.align or Enum.TextXAlignment.Center,
		color = options.textColor or theme.text,
		wrapped = true,
		truncate = true,
		zIndex = control.ZIndex + 2,
	})
	create("UIStroke", { LineJoinMode = Enum.LineJoinMode.Miter }, title)
	local fill = create("Frame", {
		Name = "HoverFill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = theme.accent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = control.ZIndex + 1,
	}, accent)
	gradient(fill, Color3.fromRGB(255, 255, 255), Color3.fromRGB(117, 117, 117))
	control.MouseEnter:Connect(function()
		TweenService:Create(fill, TweenInfo.new(0.12), { BackgroundTransparency = 0.15 }):Play()
	end)
	control.MouseLeave:Connect(function()
		TweenService:Create(fill, TweenInfo.new(0.12), { BackgroundTransparency = 1 }):Play()
	end)
	return control
end

local function connect(window, signal, callback)
	local connection = signal:Connect(callback)
	table.insert(window._connections, connection)
	return connection
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
		assert(player, "BacktrackUI.new requires options.parent outside a LocalPlayer context")
		parent = player:WaitForChild("PlayerGui")
	end

	local self = setmetatable({
		Theme = mergeTheme(options.theme),
		Images = options.images or {},
		_Connections = {},
		_connections = {},
		_controls = {},
		_flags = {},
		_values = {},
		_tabs = {},
		_panels = {},
		_keybinds = {},
		_connectionsByName = {},
		_destroyed = false,
		_popup = nil,
		_draggingWindow = false,
		_cursorRestoreState = nil,
		_cursorStepName = "BacktrackUI_MouseUnlock_" .. tostring(cursorBindingCounter),
		_cursorRenderBound = false,
		_options = options,
	}, BacktrackUI)

	self.Gui = create("ScreenGui", {
		Name = options.name or "BacktrackUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = options.displayOrder or 100,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
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
		Name = "WindowOutline",
		AnchorPoint = options.anchorPoint or Vector2.new(0.5, 0.5),
		Position = options.position or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = self.Theme.outline,
		BorderSizePixel = 0,
		ClipsDescendants = false,
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
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = self.Theme.accent,
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
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = true,
	}, self.Body)
	local headerTitle = label(self.Header, options.title or "Backtrack UI", self.Theme, {
		name = "Title",
		position = UDim2.fromOffset(2, 4),
		size = UDim2.new(1, -28, 0, 14),
		textSize = 12,
		color = self.Theme.accent,
	})
	create("UIStroke", { LineJoinMode = Enum.LineJoinMode.Miter }, headerTitle)
	self.CloseButton = create("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -7, 0, 5),
		Size = UDim2.fromOffset(15, 14),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Enum.Font.Legacy,
		Text = "X",
		TextSize = 12,
		TextColor3 = self.Theme.text,
		ZIndex = 5,
	}, self.Header)
	create("UIStroke", {}, self.CloseButton)
	self.CloseButton.Activated:Connect(function() self:SetVisible(false) end)

	self.PageOutline = create("Frame", {
		Name = "SectionOutline",
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 1, -18),
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
	self.TabBar = create("Frame", {
		Name = "Tabs",
		Size = UDim2.new(1, 0, 0, 22),
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
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalFlex = Enum.UIFlexAlignment.Fill,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 2),
	}, self.TabBar)

	self.PageHost = create("Frame", {
		Name = "SectionHolder",
		Position = UDim2.new(0, -1, 0, 19),
		Size = UDim2.new(1, 0, 1, -22),
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

	connect(self, self.Outer:GetPropertyChangedSignal("Visible"), function()
		self:_syncCursor()
	end)
	connect(self, self.Gui:GetPropertyChangedSignal("Enabled"), function()
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
	local catcher = create("TextButton", {
		Name = "PopupCatcher",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 80,
	}, self.Gui)
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
	}, self.Gui)
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
	self.Gui.Enabled = visible
	self.Outer.Visible = visible
end

function BacktrackUI:_restoreCursor()
	if self._cursorRenderBound then
		pcall(function() RunService:UnbindFromRenderStep(self._cursorStepName) end)
		self._cursorRenderBound = false
	end
	local previous = self._cursorRestoreState
	if not previous then return end
	self._cursorRestoreState = nil
	pcall(function() UserInputService.MouseBehavior = previous.mouseBehavior end)
	pcall(function() UserInputService.MouseIconEnabled = previous.mouseIconEnabled end)
end

function BacktrackUI:_syncCursor()
	local isOpen = self.Gui and self.Gui.Enabled and self.Outer and self.Outer.Visible
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
	pcall(function() UserInputService.MouseIconEnabled = true end)
	if not self._cursorRenderBound then
		local bound = pcall(function()
			RunService:BindToRenderStep(self._cursorStepName, Enum.RenderPriority.Last.Value + 1, function()
				if self._destroyed or not self.Gui or not self.Gui.Enabled or not self.Outer or not self.Outer.Visible then
					return
				end
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
				UserInputService.MouseIconEnabled = true
			end)
		end)
		self._cursorRenderBound = bound
	end
end

function BacktrackUI:SetTheme(overrides)
	local previous = {}
	for key, value in pairs(self.Theme) do previous[key] = value end
	local nextTheme = mergeTheme(overrides, self.Theme)
	for key, value in pairs(nextTheme) do self.Theme[key] = value end
	local properties = { "BackgroundColor3", "TextColor3", "TextStrokeColor3", "ImageColor3", "ScrollBarImageColor3", "BorderColor3" }
	for _, object in ipairs(self.Gui:GetDescendants()) do
		if previous.fontFace ~= nextTheme.fontFace and (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")) then
			if nextTheme.fontFace then
				pcall(function() object.FontFace = nextTheme.fontFace end)
			else
				pcall(function() object.Font = Enum.Font.Legacy end)
			end
		end
		if object:IsA("UIGradient") and object.Name == "ThemeGradient" then
			object.Color = ColorSequence.new(nextTheme.contrastTop, nextTheme.contrastBottom)
		end
		for key, oldColor in pairs(previous) do
			local newColor = nextTheme[key]
			if oldColor ~= newColor then
				if object:IsA("UIStroke") and object.Color == oldColor then object.Color = newColor end
				for _, property in ipairs(properties) do
					local ok, current = pcall(function() return object[property] end)
					if ok and current == oldColor then pcall(function() object[property] = newColor end) end
				end
			end
		end
	end
	return self.Theme
end

function BacktrackUI:SetVisible(visible)
	self:_setVisible(visible)
end

function BacktrackUI:Toggle()
	local visible = not (self.Gui.Enabled and self.Outer.Visible)
	self:_setVisible(visible)
	return visible
end

function BacktrackUI:SelectTab(tabOrName)
	for _, tab in ipairs(self._tabs) do
		if tab == tabOrName or tab.Name == tabOrName then
			tab:SetActive(true)
			return tab
		end
	end
	return nil
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
		}, self.Gui)
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

function BacktrackUI:CreatePanel(title, options)
	options = options or {}
	local panel = { _window = self, _rows = {}, Name = title or "Panel", Image = options.image }
	local frame = create("Frame", {
		Name = options.name or "UtilityPanel",
		Position = options.position or UDim2.fromOffset(24, 100),
		Size = options.size or UDim2.fromOffset(260, 220),
		BackgroundColor3 = self.Theme.outline,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, self.Gui)
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
		Position = UDim2.new(1, -4, 0, 2),
		Size = UDim2.fromOffset(13, 13),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Enum.Font.Legacy,
		Text = "X",
		TextSize = 11,
		TextColor3 = self.Theme.text,
		ZIndex = 5,
	}, inner)
	create("UIStroke", {}, close)
	close.Activated:Connect(function() frame.Visible = false end)
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
	create("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, content)
	local start, inputStart
	connect(self, bar.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
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

	function panel:AddLabel(text)
		local row = label(content, text, self._window.Theme, { size = UDim2.new(1, -8, 0, 20), position = UDim2.fromOffset(4, 0), wrapped = true })
		table.insert(self._rows, row)
		return row
	end
	function panel:AddSection(name)
		local section = createSection(self._window, content, name or "Section", "PanelSection_" .. tostring(#self._rows + 1), math.max(120, self.Frame.Size.Y.Offset - 36))
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
		return setmetatable({ _window = self._window, Frame = frame, _sectionCount = 0 }, Column)
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
		frame.Visible = visible ~= false
	end
	function panel:Toggle()
		frame.Visible = not frame.Visible
		return frame.Visible
	end
	function panel:Destroy()
		if frame.Parent then frame:Destroy() end
		for index, item in ipairs(self._window._panels) do
			if item == self then table.remove(self._window._panels, index) break end
		end
		if self._window.Dock then self._window.Dock:Refresh() end
	end
	table.insert(self._panels, panel)
	if self.Dock then self.Dock:Refresh() end
	return panel
end

function BacktrackUI:CreateWatermark(text, options)
	options = options or {}
	local badge = create("TextLabel", {
		Name = "Watermark",
		Position = options.position or UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(180, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = self.Theme.surface,
		BorderSizePixel = 0,
		Font = Enum.Font.Legacy,
		Text = "  " .. tostring(text or "Backtrack UI") .. "  ",
		TextColor3 = self.Theme.text,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, self.Gui)
	corner(badge, 3)
	stroke(badge, self.Theme.border, 1)
	local start, inputStart
	connect(self, badge.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			start, inputStart = badge.Position, input.Position
		end
	end)
	connect(self, UserInputService.InputChanged, function(input)
		if start and inputStart and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - inputStart
			badge.Position = UDim2.new(start.X.Scale, start.X.Offset + delta.X, start.Y.Scale, start.Y.Offset + delta.Y)
		end
	end)
	connect(self, UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then start = nil end
	end)
	return {
		Object = badge,
		SetText = function(_, value) badge.Text = "  " .. tostring(value or "") .. "  " end,
		SetVisible = function(_, visible) badge.Visible = visible ~= false end,
		Destroy = function() badge:Destroy() end,
	}
end

function BacktrackUI:CreateDock(options)
	options = options or {}
	if self.Dock and self.Dock.Frame.Parent then self.Dock:Destroy() end
	local dock = { _window = self, _buttons = {} }
	local frame = create("Frame", {
		Name = "BacktrackDock",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = options.position or UDim2.new(0.5, 0, 1, -120),
		Size = options.size or UDim2.fromOffset(157, 39),
		BackgroundColor3 = self.Theme.outline,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 10,
	}, self.Gui)
	dock.Frame = frame
	local glowImage = self.Images.glow4 or self.Images.glow
	if glowImage then
		create("ImageLabel", {
			Name = "DockGlow",
			Position = UDim2.fromOffset(-20, -20),
			Size = UDim2.new(1, 40, 1, 40),
			BackgroundTransparency = 1,
			Image = glowImage,
			ImageColor3 = self.Theme.glow,
			ImageTransparency = 0.8,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(21, 21, 79, 79),
			ZIndex = 9,
		}, frame)
	end
	local inline = create("Frame", {
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = self.Theme.inline,
		BorderSizePixel = 0,
		ZIndex = 11,
	}, frame)
	local face = create("Frame", {
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = self.Theme.contrastTop,
		BorderSizePixel = 0,
		ZIndex = 12,
	}, inline)
	gradient(face, self.Theme.contrastTop, self.Theme.contrastBottom)
	create("Frame", {
		Name = "PinkCap",
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = self.Theme.accent,
		BorderSizePixel = 0,
		ZIndex = 13,
	}, face)
	local holder = create("Frame", {
		Name = "DockButtons",
		Position = UDim2.fromOffset(4, 6),
		Size = UDim2.new(1, -8, 1, -10),
		BackgroundTransparency = 1,
		ZIndex = 14,
	}, face)
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 5),
	}, holder)
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
	function dock:AddButton(name, icon, callback)
		local image = type(icon) == "string" and (self._window.Images[icon] or (icon:match("^rbxassetid://") and icon)) or nil
		local glyph = icon
		if type(icon) == "string" and not image and icon:match("^[%w_%-]+$") then glyph = icon:sub(1, 1) end
		local item = button(holder, image and "" or (glyph or tostring(name or "?"):sub(1, 1)), self._window.Theme, {
			name = "DockButton",
			size = UDim2.fromOffset(25, 25),
			background = self._window.Theme.background,
			border = self._window.Theme.inline,
			textSize = 13,
			zIndex = 15,
		})
		if image then
			create("ImageLabel", {
				Name = "Icon",
				Position = UDim2.fromOffset(3, 3),
				Size = UDim2.new(1, -6, 1, -6),
				BackgroundTransparency = 1,
				Image = image,
				ImageColor3 = self._window.Theme.accent,
				ResampleMode = Enum.ResamplerMode.Pixelated,
				ZIndex = 16,
			}, item)
		end
		item.LayoutOrder = #self._buttons + 1
		item.Activated:Connect(function()
			if callback then
				invoke(callback)
			else
				self._window.Gui.Enabled = true
				self._window.Outer.Visible = true
			end
		end)
		table.insert(self._buttons, item)
		return item
	end
	function dock:Refresh()
		for _, item in ipairs(self._buttons) do item:Destroy() end
		table.clear(self._buttons)
		self:AddButton("Main", options.icon or "main", function()
			self._window.Gui.Enabled = true
			self._window.Outer.Visible = true
		end)
		for _, panel in ipairs(self._window._panels) do
			self:AddButton(panel.Name, panel.Image, function() panel:Toggle() end)
		end
	end
	function dock:SetVisible(visible) frame.Visible = visible ~= false end
	function dock:Destroy() if frame.Parent then frame:Destroy() end end
	dock:Refresh()
	self.Dock = dock
	return dock
end

function BacktrackUI:Destroy()
	if self._destroyed then return end
	self._destroyed = true
	self:_restoreCursor()
	self:_closePopup()
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
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
	if type(name) == "table" then
		iconText = name.icon or name.image or iconText
		name = name.name or name.title
	end
	local index = #self._tabs + 1
	local tab = setmetatable({ _window = self, Name = name or ("Tab " .. index), _iconText = iconText, _columns = {}, _sectionCount = 0 }, Tab)
	tab.Button = create("TextButton", {
		Name = "TabButton",
		AutoButtonColor = false,
		Size = UDim2.new(0, 0, 1, -2),
		BackgroundColor3 = self.Theme.outline,
		BorderSizePixel = 0,
		Text = "",
		ZIndex = 5,
	}, self.TabBar)
	tab.Inline = create("Frame", {
		Name = "Inline",
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, 0),
		BackgroundColor3 = self.Theme.inline,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, tab.Button)
	tab.Face = create("Frame", {
		Name = "Face",
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -1),
		BackgroundColor3 = self.Theme.contrastTop,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, tab.Inline)
	tab.FaceGradient = gradient(tab.Face, self.Theme.contrastTop, self.Theme.contrastBottom)
	tab.Label = label(tab.Face, tab.Name, self.Theme, {
		name = "TabLabel",
		textSize = 12,
		align = Enum.TextXAlignment.Center,
		color = self.Theme.text,
		zIndex = 6,
	})
	tab.Page = create("Frame", {
		Name = "Page_" .. tostring(index),
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
	tab.Button.Activated:Connect(function() tab:SetActive(true) end)
	table.insert(self._tabs, tab)
	if index == 1 then tab:SetActive(true) end
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
		local column = setmetatable({ _tab = self, Frame = frame }, Column)
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
		return
	end
	for _, tab in ipairs(self._window._tabs) do
		tab.Page.Visible = tab == self
		local selected = tab == self
		tab.Label.TextColor3 = selected and self._window.Theme.accent or self._window.Theme.text
		tab.Face.Size = selected and UDim2.new(1, -2, 1, 0) or UDim2.new(1, -2, 1, -1)
		tab.FaceGradient.Rotation = selected and -90 or 90
	end
	self._window.ActiveTab = self
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
	return createSection(window, self.Frame, title, "Section_" .. tostring(self._sectionCount))
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
	return setmetatable({ _window = self._window or self._tab._window, Frame = frame, _sectionCount = 0 }, Column)
end

function Column:MultiSection(options)
	if type(options) == "string" then options = { names = { options } } end
	options = options or {}
	local names = options.names or { "Section A", "Section B" }
	local window = self._window or self._tab._window
	local multi = setmetatable({ _window = window, Name = options.name or "MultiSection", Sections = {}, Tabs = {} }, MultiSection)
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
	local name = options.text or options.name or "Button"
	local row, click
	local holder = self._buttonHolder
	if holder and holder.Parent == self.Content then
		row = holder
		click = sourceActionButton(holder, name, self._window.Theme, {
			position = UDim2.fromOffset(0, 2),
			size = UDim2.new(1, -27, 0, 18),
			textSize = options.textSize or 12,
			textColor = options.textColor,
		})
	else
		local text
		row, text = self:_row(options.name or name, options.height or 28, true)
		click = sourceActionButton(row, name, self._window.Theme, {
			position = UDim2.fromOffset(2, 2),
			size = UDim2.new(1, -4, 1, -4),
			textSize = options.textSize or 12,
			textColor = options.textColor,
		})
		text.Visible = false
	end
	local control = { _section = self, _row = row, Name = name, Flag = options.flag }
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
		invoke(options.callback)
	end
	click.Activated:Connect(control.Activate)
	if options.tooltip then self._window:AddTooltip(row, options.tooltip) end
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
		if not silent then invoke(control.Callback, control.active, control.key, control.mode) end
		return control.key
	end
	function control:Get()
		return { key = control.key, mode = control.mode, active = control.active }
	end
	function control:SetActive(value, silent)
		control.active = control.mode == "Always" or (control.mode ~= "Never" and value == true)
		window._values[control.Flag] = { key = control.key, mode = control.mode, active = control.active }
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
			local function updateSquare(input)
				local position = UserInputService:GetMouseLocation()
				saturation = math.clamp((position.X - square.AbsolutePosition.X) / square.AbsoluteSize.X, 0, 1)
				brightness = 1 - math.clamp((position.Y - square.AbsolutePosition.Y) / square.AbsoluteSize.Y, 0, 1)
				applyHSV()
			end
			local function updateHue()
				local position = UserInputService:GetMouseLocation()
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
	}, window.Gui)
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
		}, window.Gui)
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
Tab.column = Tab.AddColumn
Tab.section = Tab.AddSection
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
Section.label = Section.Label
Section.keybind = Section.Keybind
Section.colorpicker = Section.Colorpicker
Section.output = Section.Output
Section.list = Section.List
Section.button_holder = Section.ButtonHolder
Section.configuration = Section.Configuration

return BacktrackUI
