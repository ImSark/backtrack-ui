-- Original camera-aligned lens renderer for Liquid Glass UI.
-- Technique inspiration: https://devforum.roblox.com/t/4416219
-- The implementation and meshes in this repository are independent work.

local Renderer = {}
Renderer.__index = Renderer

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local AssetService = game:GetService("AssetService")
local InsertService = game:GetService("InsertService")

local defaultAssets = "https://raw.githubusercontent.com/ImSark/backtrack-ui/main/assets/liquid-glass/"
local white = Color3.new(1, 1, 1)
local black = Color3.new(0, 0, 0)
local rotations = { CFrame.new(), CFrame.Angles(0, 0, math.pi / 2), CFrame.Angles(0, 0, math.pi), CFrame.Angles(0, 0, -math.pi / 2) }

local function configure(part, strength)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Glass
	part.Color = black
	-- Values above one retain the glass refraction pass without an opaque fill.
	part.Transparency = strength
	part.Reflectance = 0
	part.TextureID = ""
	part.Size = Vector3.new(1, 1, 1)
end

local function importMesh(uri)
	local errors = {}
	local ok, result = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromUri(uri), {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Precise,
		})
	end)
	if ok and result and result:IsA("MeshPart") then return result end
	table.insert(errors, tostring(result))
	if ok and result then result:Destroy() end
	ok, result = pcall(function()
		return InsertService:CreateMeshPartAsync(uri, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Precise)
	end)
	if ok and result and result:IsA("MeshPart") then return result end
	if ok and result then result:Destroy() end
	table.insert(errors, tostring(result))
	error("MeshPart import failed: " .. table.concat(errors, " | "))
end

local function loadTemplates(self)
	local supplied = self.Options.templates
	local uris = self.Options.meshes
	local registerAsset = getcustomasset or getsynasset
	local folder = self.Options.assetFolder or "liquid_glass_assets"
	if not supplied and not uris then
		assert(type(writefile) == "function" and type(registerAsset) == "function", "Refraction requires writefile and getcustomasset, or supplied MeshPart templates/mesh URIs")
		if type(isfolder) == "function" and type(makefolder) == "function" then
			if not isfolder(folder) then makefolder(folder) end
		else
			folder = "."
		end
	end
	local nonce = HttpService:GenerateGUID(false):gsub("[^%w]", "")
	for _, kind in ipairs({ "center", "edge", "corner" }) do
		local part
		if supplied then
			assert(supplied[kind] and supplied[kind]:IsA("MeshPart"), "Missing " .. kind .. " MeshPart template")
			part = supplied[kind]:Clone()
		else
			local uri = uris and uris[kind]
			if not uri then
				assert(not uris, "Missing " .. kind .. " mesh URI")
				local base = self.Options.assetBaseUrl or defaultAssets
				if base:sub(-1) ~= "/" then base = base .. "/" end
				local bytes = game:HttpGet(base .. kind .. ".mesh?t=" .. nonce)
				assert(bytes:sub(1, 13) == "version 2.00\n", "Invalid " .. kind .. " lens data")
				local filename = folder .. "/lens_" .. nonce .. "_" .. kind .. ".mesh"
				writefile(filename, bytes)
				table.insert(self._files, filename)
				uri = registerAsset(filename)
			end
			part = importMesh(uri)
		end
		self._templates[kind] = part
		configure(part, self.Strength)
	end
end

-- Solve the intersection of a viewport ray with the camera's depth plane.
local function project(camera, renderFrame, x, y, depth)
	local ray = camera:ViewportPointToRay(x, y)
	local denominator = ray.Direction:Dot(renderFrame.LookVector)
	assert(denominator > 0.00001, "Invalid camera projection")
	local originDepth = (ray.Origin - renderFrame.Position):Dot(renderFrame.LookVector)
	return ray.Origin + ray.Direction * ((depth - originDepth) / denominator)
end

local function bounds(gui)
	if not gui.Parent or not gui.Visible then return nil end
	local pos, size = gui.AbsolutePosition, gui.AbsoluteSize
	if size.X < 1 or size.Y < 1 then return nil end
	local angle = math.rad(gui.AbsoluteRotation)
	local cx, cy = pos.X + size.X / 2, pos.Y + size.Y / 2
	local halfX = (math.abs(math.cos(angle)) * size.X + math.abs(math.sin(angle)) * size.Y) / 2
	local halfY = (math.abs(math.sin(angle)) * size.X + math.abs(math.cos(angle)) * size.Y) / 2
	local inset = Vector2.new(0, 0)
	local parent = gui.Parent
	while parent do
		if parent:IsA("ScreenGui") then
			if not parent.Enabled then return nil end
			if not parent.IgnoreGuiInset then inset = GuiService:GetGuiInset() end
		elseif parent:IsA("GuiObject") then
			if not parent.Visible then return nil end
			if parent:IsA("CanvasGroup") and parent.GroupTransparency >= 1 then return nil end
			if parent.ClipsDescendants then
				-- Hide partially clipped lenses instead of leaking glass outside a scroller.
				local p, s = parent.AbsolutePosition, parent.AbsoluteSize
				if parent.AbsoluteRotation ~= 0 or cx - halfX < p.X - 0.5 or cy - halfY < p.Y - 0.5
					or cx + halfX > p.X + s.X + 0.5 or cy + halfY > p.Y + s.Y + 0.5 then return nil end
			end
		end
		parent = parent.Parent
	end
	local corner = gui:FindFirstChildOfClass("UICorner")
	local radius = corner and (corner.CornerRadius.Offset + corner.CornerRadius.Scale * math.min(size.X, size.Y)) or 0
	return cx + inset.X, cy + inset.Y, size.X, size.Y, math.clamp(radius, 0, math.min(size.X, size.Y) / 2), angle
end

local function setShown(self, surface, shown)
	if surface.Shown == shown then return end
	surface.Shown = shown
	surface.Model.Parent = shown and self.Folder or nil
end

function Renderer.new(options)
	options = options or {}
	local self = setmetatable({
		Options = options, Enabled = true, Status = "loading", LastError = nil,
		Strength = math.clamp(tonumber(options.strength) or 3, 1.01, 8),
		Thickness = math.clamp(tonumber(options.thickness) or 7, 1, 32),
		Depth = math.clamp(tonumber(options.depth) or 2, 0.8, 10),
		MaxSurfaces = math.max(1, math.floor(tonumber(options.maxSurfaces) or 32)),
		_surfaces = {}, _count = 0, _templates = {}, _files = {}, _destroyed = false,
	}, Renderer)
	local ok, err = pcall(function()
		loadTemplates(self)
		self.Folder = Instance.new("Folder")
		self.Folder.Name = (options.name or "LiquidGlassUI") .. "_Refraction"
		self.Folder.Parent = Workspace
		self._renderConnection = RunService.RenderStepped:Connect(function()
			if self._destroyed then return end
			local success, renderError = pcall(self._step, self)
			if not success then
				self.LastError = tostring(renderError)
				self.Status = "unavailable"
				self:SetEnabled(false)
				if self._renderConnection then self._renderConnection:Disconnect() end
				if type(self.Options.onError) == "function" then self.Options.onError(self.LastError) end
			end
		end)
	end)
	if not ok then self:Destroy(); error(err, 0) end
	self.Status = "ready"
	return self
end

function Renderer:Attach(gui, options)
	assert(not self._destroyed, "Renderer is destroyed")
	assert(gui and gui:IsA("GuiObject"), "Attach requires a GuiObject")
	if self._surfaces[gui] then return self._surfaces[gui] end
	if self._count >= self.MaxSurfaces then return nil, "Refraction surface limit reached" end
	options = options or {}
	local model = Instance.new("Model")
	model.Name = "Lens_" .. gui.Name
	local highlight = Instance.new("Highlight")
	highlight.Adornee = model
	highlight.FillColor = black
	highlight.FillTransparency = 0.95
	highlight.OutlineColor = white
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = model
	local surface = { Gui = gui, Model = model, Pieces = {}, Shown = false,
		Depth = math.max(0.65, self.Depth - (tonumber(options.layer) or 0) * 0.14), Key = nil }
	for _, item in ipairs({
		{ "center", "center" }, { "left", "edge" }, { "right", "edge" }, { "bottom", "edge" }, { "top", "edge" },
		{ "bottomLeft", "corner" }, { "topLeft", "corner" }, { "topRight", "corner" }, { "bottomRight", "corner" },
	}) do
		local part = self._templates[item[2]]:Clone()
		part.Name = item[1]
		surface.Pieces[item[1]] = { Part = part }
	end
	self._surfaces[gui] = surface
	self._count = self._count + 1
	surface.Connection = gui.Destroying:Connect(function() self:Detach(gui) end)
	return surface
end

function Renderer:Detach(gui)
	local surface = self._surfaces[gui]
	if not surface then return end
	self._surfaces[gui] = nil
	self._count = self._count - 1
	if surface.Connection then surface.Connection:Disconnect() end
	for _, piece in pairs(surface.Pieces) do piece.Part:Destroy() end
	surface.Model:Destroy()
end

function Renderer:_layout(surface, width, height, radius, sx, sy)
	local key = { width, height, radius, sx, sy, self.Thickness }
	local same = surface.Key ~= nil
	if same then for i, value in ipairs(key) do if math.abs(surface.Key[i] - value) > 0.000001 then same = false; break end end end
	if same then return end
	surface.Key = key
	local innerW, innerH = width - radius * 2, height - radius * 2
	local thickness = self.Thickness * math.min(sx, sy)
	local function patch(name, x, y, w, h, quarterTurns)
		local piece = surface.Pieces[name]
		piece.Active = w > 0.001 and h > 0.001
		piece.Part.Parent = piece.Active and surface.Model or nil
		if not piece.Active then return end
		-- A subpixel overlap closes numerical seams between the patches.
		local padding = 0.2
		local rotated = quarterTurns == 1 or quarterTurns == 3
		piece.Part.Size = Vector3.new((w + padding) * (rotated and sy or sx), (h + padding) * (rotated and sx or sy), thickness)
		-- The flat back of each patch lies on the projected GUI plane.
		piece.Offset = CFrame.new(x * sx, y * sy, thickness / 2) * rotations[quarterTurns + 1]
	end
	patch("center", 0, 0, innerW, innerH, 0)
	patch("left", -width / 2 + radius / 2, 0, radius, innerH, 0)
	patch("right", width / 2 - radius / 2, 0, radius, innerH, 2)
	patch("bottom", 0, -height / 2 + radius / 2, radius, innerW, 1)
	patch("top", 0, height / 2 - radius / 2, radius, innerW, 3)
	patch("bottomLeft", -width / 2 + radius / 2, -height / 2 + radius / 2, radius, radius, 0)
	patch("topLeft", -width / 2 + radius / 2, height / 2 - radius / 2, radius, radius, 3)
	patch("topRight", width / 2 - radius / 2, height / 2 - radius / 2, radius, radius, 2)
	patch("bottomRight", width / 2 - radius / 2, -height / 2 + radius / 2, radius, radius, 1)
	if radius < 0.001 then patch("center", 0, 0, width, height, 0) end
end

function Renderer:_step()
	local camera = Workspace.CurrentCamera
	for gui, surface in pairs(self._surfaces) do
		local cx, cy, width, height, radius, angle
		if camera and self.Enabled then cx, cy, width, height, radius, angle = bounds(gui) end
		if not cx then
			setShown(self, surface, false)
		else
			local frame = camera:GetRenderCFrame()
			local center = project(camera, frame, cx, cy, surface.Depth)
			local dx = project(camera, frame, cx + 1, cy, surface.Depth) - center
			local dy = project(camera, frame, cx, cy + 1, surface.Depth) - center
			local base = CFrame.fromMatrix(center, dx.Unit, -dy.Unit) * CFrame.Angles(0, 0, -angle)
			self:_layout(surface, width, height, radius, dx.Magnitude, dy.Magnitude)
			for _, piece in pairs(surface.Pieces) do if piece.Active then piece.Part.CFrame = base * piece.Offset end end
			setShown(self, surface, true)
		end
	end
end

function Renderer:SetEnabled(enabled)
	self.Enabled = enabled ~= false
	if not self.Enabled then for _, surface in pairs(self._surfaces) do setShown(self, surface, false) end end
end

function Renderer:SetStrength(strength)
	self.Strength = math.clamp(tonumber(strength) or 3, 1.01, 8)
	for _, surface in pairs(self._surfaces) do for _, piece in pairs(surface.Pieces) do piece.Part.Transparency = self.Strength end end
	for _, template in pairs(self._templates) do template.Transparency = self.Strength end
	return self.Strength
end

function Renderer:Destroy()
	if self._destroyed then return end
	self._destroyed = true
	if self._renderConnection then self._renderConnection:Disconnect() end
	local attached = {}
	for gui in pairs(self._surfaces) do table.insert(attached, gui) end
	for _, gui in ipairs(attached) do self:Detach(gui) end
	for _, template in pairs(self._templates) do template:Destroy() end
	if self.Folder then self.Folder:Destroy() end
	if type(delfile) == "function" then for _, filename in ipairs(self._files) do pcall(delfile, filename) end end
	table.clear(self._files)
end

return Renderer
