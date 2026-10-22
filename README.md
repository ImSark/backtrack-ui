# Backtrack UI

A standalone Luau UI library based on the menu in the [provided script](https://raw.githubusercontent.com/GLAMOHGA/Project-Delta/refs/heads/main/backtrack.tech.txt). The example recreates the four main tabs (`Combat`, `Players`, `Misc`, and `Visuals`) plus the separate `Style`, `Configurations`, `Playerlist`, and `Output` windows. It follows the source window sizes and screen-relative positions, square 25×25 dock icons, rose accent, dark blue-grey gradients, pixel icons, Tahoma font, and watermark treatment. Dock icons tint rose while their own window is open and inline-grey while it is closed.

The library builds interface elements and invokes callbacks supplied by the host script; it does not include the source script's game behavior. Its optional Lua Modules panel supports custom module definitions with settings and enable/disable lifecycle callbacks, as well as one-shot scripts. The executor example uses `loadstring(game:HttpGet(...))`; its runtime cache-buster requests fresh example and library code each run. It loads the PNG UI images and original Tahoma font through executor asset APIs. A custom `FontFace` can also be supplied as `theme.fontFace`.

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
- `menu:CreateLuaModuleManager(options)` creates an optional Lua module editor and manager. Add its panel to a dock explicitly with `dock:AddPanel(manager.Panel)`. Modules can declare settings, enable/disable behavior, and setting-change callbacks; their Settings button opens generated controls. Supported setting types are `toggle`, `slider`, `dropdown`, `multidropdown`, `textbox`, `colorpicker`, `keybind`, `button`, and `label`. A module receives `menu`, the manager, and its module context as chunk arguments (`local menu, manager, module = ...`). Definition sources are compiled when first enabled or run and require executor `loadstring` support. Legacy scripts that return no definition remain available as one-shot **Run** modules.

Example module source to paste into the editor:

```lua
local menu, manager, module = ...

return {
    Settings = {
        Active = { type = "toggle", default = true },
        Strength = { type = "slider", min = 0, max = 100, step = 5, default = 35 },
        Mode = { type = "dropdown", items = { "Quiet", "Balanced", "Loud" }, default = "Balanced" },
        Accent = { type = "colorpicker", default = Color3.fromRGB(255, 98, 127), alpha = 1 },
        Shortcut = { type = "keybind", key = Enum.KeyCode.RightShift, mode = "Toggle" },
        Label = { type = "textbox", default = "My module" },
        Reset = { type = "button", text = "Reset", callback = function(module)
            module:Set("Strength", 35)
        end },
    },

    OnEnable = function(module, menu, manager)
        local color = module:Get("Accent") -- { color = Color3, alpha = number }
        menu:Notify("Enabled " .. module:Get("Label"), 3, "success")
    end,

    OnSettingChanged = function(name, value, module)
        -- Apply changed settings to your module's behavior here.
    end,

    OnDisable = function(module, menu, manager)
        -- Stop or clean up anything started in OnEnable.
    end,
}
```

The module context provides `Get(name)`, `Set(name, value, silent)`, `Notify(...)`, `Enable()`, `Disable()`, `IsEnabled()`, and `OpenSettings()`. `OnEnable` and `OnDisable` receive `(module, menu, manager)`. A setting's `callback`/`onChanged` receives `(value, module, name)`; the module-level `OnSettingChanged` receives `(name, value, module)`. Color picker values use `{ color = Color3, alpha = number }`.

The manager API also exposes `AddModule(name, source, options)`, `GetModule(name)`, `GetModules()`, `LoadModule(name)`, `OpenSettings(name)`, `EnableModule(name)`, `DisableModule(name)`, `SetModuleEnabled(name, bool)`, `RunModule(name)`, `RemoveModule(name)`, and `Destroy()`. Definitions can be registered directly without source text:

```lua
manager:AddModule("Demo", "", {
    Settings = { Enabled = { type = "toggle", default = true } },
    OnEnable = function(module) print("Demo enabled", module:Get("Enabled")) end,
    OnDisable = function(module) print("Demo disabled") end,
})
```
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
