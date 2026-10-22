# Backtrack UI

A standalone Luau UI library based on the menu in the [provided script](https://raw.githubusercontent.com/GLAMOHGA/Project-Delta/refs/heads/main/backtrack.tech.txt). The example recreates the four main tabs (`Combat`, `Players`, `Misc`, and `Visuals`) plus the separate `Style`, `Configurations`, `Playerlist`, and `Output` windows. It follows the source window sizes and screen-relative positions, square 25×25 dock icons, rose accent, dark blue-grey gradients, pixel icons, Tahoma font, and watermark treatment. Dock icons tint rose while their own window is open and inline-grey while it is closed.

The library builds interface elements and invokes callbacks supplied by the host script; it does not include the source script's game behavior. Its optional Lua Modules dock panel runs user-entered module source only when the user clicks **Run**. The executor example uses `loadstring(game:HttpGet(...))`; its runtime cache-buster requests fresh example and library code each run. It loads the PNG UI images and original Tahoma font through executor asset APIs. A custom `FontFace` can also be supplied as `theme.fontFace`.

## Executor loader

Use this same command each time. The unique query string fetches fresh example and library code from `main`; image and font assets are cached locally by the example:

```lua
local url = "https://raw.githubusercontent.com/ImSark/backtrack-ui/main/example.client.lua"
local cacheBuster = tostring(math.floor(os.clock() * 1000000))
loadstring(game:HttpGet(url .. "?t=" .. cacheBuster))()
```

## Library API

The executor example above handles asset loading and opens the full demo. For a custom executor menu, load the library first:

`BacktrackUI.new()` creates the window shell only. It does not add starter tabs, controls, dock tabs, or utility panels. Build the interface by adding the pieces you need; the example client explicitly builds its own demo layout.

```lua
local url = "https://raw.githubusercontent.com/ImSark/backtrack-ui/main/backtrack_ui.lua"
local cacheBuster = tostring(math.floor(os.clock() * 1000000))
local BacktrackUI = loadstring(game:HttpGet(url .. "?t=" .. cacheBuster))()

local menu = BacktrackUI.new({
    title = "Example Menu",
    toggleKey = Enum.KeyCode.RightShift,
    theme = {
        accent = Color3.fromRGB(255, 98, 127),
    },
})

local tab = menu:AddTab("General")
local left = tab:Column()
local right = tab:Column()

local settings = left:AddSection("Settings")
settings:Toggle({
    name = "Enabled",
    flag = "enabled",
    default = true,
    callback = function(value)
        print("Enabled:", value)
    end,
})
settings:Slider({
    name = "Amount",
    flag = "amount",
    min = 0,
    max = 100,
    step = 5,
    default = 25,
    suffix = "%",
})

local display = right:AddSection("Display")
display:Dropdown({
    name = "Mode",
    flag = "mode",
    items = { "Quiet", "Normal", "Loud" },
    default = "Normal",
})
display:Button({
    name = "Show notice",
    callback = function()
        menu:Notify("The button callback ran.", 3, "success")
    end,
})
```

Tabs and buttons accept style overrides and return handles so they can be edited or removed later:

```lua
local customTab = menu:AddTab({
    name = "Tools",
    iconText = "T",
    width = 100,
    activeColor = Color3.fromRGB(80, 220, 150),
    tooltip = "Custom tools",
})
local toolSection = customTab:Column():AddSection("Actions")
local runButton = toolSection:AddButton({
    text = "Run",
    style = {
        accentColor = Color3.fromRGB(80, 220, 150),
        surfaceColor = Color3.fromRGB(28, 42, 36),
        hoverColor = Color3.fromRGB(80, 220, 150),
    },
    callback = function() print("Run") end,
})
runButton:SetText("Run again")
```

`CreateDock()` also starts empty. `AddTab()` returns a configurable dock item handle, `AddButton()` adds an action button, and `AddWindow()` / `AddPanel()` explicitly link windows. Create the optional Lua Modules panel separately when you want it:

```lua
local modules = menu:CreateLuaModuleManager()
local dock = menu:CreateDock({ buttonSize = 25, spacing = 5 })
dock:AddWindow("Main", menu, "main")
dock:AddPanel(modules.Panel, { name = "Lua Modules", icon = "lua" })
dock:AddTab({ name = "Quick action", iconText = "!", callback = function()
    print("Quick action")
end })

modules:AddModule("Notice", [[
local menu = ...
menu:Notify("The module ran.", 3, "success")
]])
```

When no `parent` is supplied, `BacktrackUI.new` uses the executor's `gethui`/`get_hidden_gui` container when available, then falls back to the local player's `PlayerGui`. Pass `parent` to host the GUI elsewhere. `toggleKey` accepts a Roblox `Enum.KeyCode`.

The [example client](example.client.lua) loads the public library directly from GitHub with `loadstring` and demonstrates the source UI arrangement. Its callbacks are inert examples.

## Components

- Window with draggable title bar, tab navigation, visibility toggle, cursor release while open, cursor-state restoration on close, and theme overrides.
- Equal-width tabs, fill-height columns and sections, nested columns, source-style section tabs, scrollable sections, and collapsible configuration groups.
- Toggle, slider, single and multiselect dropdown, textbox, action button, label, divider, keybind, and HSV color picker with opacity.
- Source-style button-holder rows, multi-button rows, scrolling lists, output logs, hover tooltips, and notifications.
- Source-sized detached utility panels, a customizable draggable dock with manually added icon buttons, pixel cursor, keybind list, watermark, and notifications. `dock:AddWindow()` links a panel or main window; `dock:AddTab()` and `dock:AddButton()` add custom actions. Nothing is inserted into the dock automatically.
- SVG icons are included in [`assets/icons`](assets/icons/). Original PNG icons and the glow image are in [`assets/roblox`](assets/roblox); the executor example downloads these through executor asset APIs.
- `control:Get()`, `control:Set(value)`, `control:SetVisible(bool)`, plus window-level `GetValues()` and `SetValues(values)` for application-owned configuration persistence.
- `menu:CreateWatermark(text)` returns a draggable watermark handle with `SetText`, `SetVisible`, `SetPosition`, `GetPosition`, and `Destroy`. It respects the Roblox topbar inset by default; pass `position`, `displayOrder`, or `ignoreGuiInset` in its options to customize placement.
- `menu:CreateLuaModuleManager(options)` creates an optional Lua source editor panel. Add its panel to a dock explicitly with `dock:AddPanel(manager.Panel)`. Users can add, run, and remove modules for the current UI session. The manager is also available as `menu.LuaModules`; `AddModule(name, source)`, `RunModule(name)`, `RemoveModule(name)`, and `GetModules()` are available. A module receives `menu` and the manager as its first two chunk arguments (`local menu, moduleManager = ...`). Source runs only when the user clicks **Run** and requires executor `loadstring` support.
- `menu:SetTheme({ accent = Color3.fromRGB(...) })` updates the current GUI palette.

Controls accept a `flag` and `callback`. Flags default to a generated name when omitted. A color picker returns `{ color = Color3, alpha = number }` from `Get()` and calls its callback with `(color, alpha)`. A keybind returns `{ key = EnumItem, mode = string, active = boolean }`.

## Builder-style aliases

`Column:MultiSection({ names = { ... } })` returns one section object per name. Each section is selected by its inline tab; a section exposes `SetActive()` through its `MultiSection` field. `Column:Column()` creates a nested fill-height column, and detached panels support `panel:AddColumn()`.

`Section:ButtonHolder()` starts a horizontal action row. Following `Section:Button()` calls are placed in that row until another button holder is created. Use `Section:MultiButton()` when the buttons should stay inside a single labeled row.

`Section:AddButton()` is an alias for `Section:Button()`. Its handle supports `SetText`, `SetCallback`, `SetVisible`, `SetTooltip`, `SetStyle`, and `Destroy`. Main tabs support the matching add, visibility, order, icon, text, style, callback, and destroy operations; `menu:GetTabs()`, `menu:RemoveTab(nameOrHandle)`, and `menu:ClearTabs()` manage them. Dock tabs also have mutable handles; use `dock:RemoveTab(nameOrHandle)` or `dock:Clear()` to remove items.

The lowercase methods are available for compact builder code:

```lua
local menu = BacktrackUI:window({ name = "Example" })
local section = menu:tab({ name = "General" }):column():section({ name = "Settings" })
section:toggle({ name = "Enabled", flag = "enabled" })
```

The library intentionally leaves file/config storage, application state, and every control callback to the host script.

See [`assets/README.md`](assets/README.md) for the icon pack, source PNGs, and notes about uploading image assets to Roblox.
