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

## Separate Liquid Glass library

`liquid_glass_ui.lua` is an independent library with floating pill navigation and camera-aligned curved MeshPart lenses that refract the 3D world. It loads `liquid_glass_renderer.lua` and the original lens geometry in `assets/liquid-glass/`. The example replaces its previous window on reload and leaves global blur off. Load it with:

```lua
local url = "https://raw.githubusercontent.com/ImSark/backtrack-ui/main/liquid_glass_example.client.lua"
local cacheBuster = tostring(math.floor(os.clock() * 1000000))
loadstring(game:HttpGet(url .. "?t=" .. cacheBuster))()
```

Or load the library directly and build only the tabs and controls you need:

```lua
local url = "https://raw.githubusercontent.com/ImSark/backtrack-ui/main/liquid_glass_ui.lua"
local cacheBuster = tostring(math.floor(os.clock() * 1000000))
local LiquidGlassUI = loadstring(game:HttpGet(url .. "?t=" .. cacheBuster))()

local ui = LiquidGlassUI.new({ title = "My Glass Menu", toggleKey = Enum.KeyCode.RightShift })
local tab = ui:AddTab({ name = "General", iconText = "◇" })
local section = tab:AddSection("Settings")
section:Toggle({ name = "Enabled", default = true, callback = function(value) print(value) end })
section:Slider({ name = "Amount", min = 0, max = 100, default = 40 })
section:Button({ name = "Notify", callback = function() ui:Notify("Hello", 3, "success") end })
```

It includes labels, buttons, toggles, sliders, dropdowns, textboxes, color pickers, and keybinds. `SetTheme`, `SetBlur`, `SetRefractionStrength`, `GetRefractionStatus`, `SetVisible`, `Toggle`, `SetMinimized`, and `Destroy` control the window after creation. See [liquid_glass_example.client.lua](liquid_glass_example.client.lua) for a complete demo.

Use `theme.glassTransparency` and `theme.controlTransparency` to adjust the material. The window starts at `0.34` transparency and changes to `0.84` when refraction is ready unless an explicit theme transparency was supplied. The colors `glassTop`, `glass`, and `glassBottom` tint its surface; `text` and `muted` control the ink. `replaceExisting = true` destroys a previous interface with the same `name`, disconnects its handlers, and removes its lenses and camera blur. Leave it off to create separate named windows.

Refraction requires executor file/custom-asset support and MeshPart import support. Graphics quality must support Roblox Glass refraction; it cannot refract other UI and does not render on mobile. A loading error sets `RefractionStatus = "unavailable"`, records `RefractionError`, and calls `onRefractionError(message, window)`; the example reports this fallback rather than silently claiming the effect loaded. `onRefractionReady(renderer, window)` runs when mesh setup completes. These states describe setup, not a guarantee that the player's graphics settings display refraction.

Set `refraction = false` for the translucent UI without meshes, or `refractionControls = false` to reserve lenses for the window, navigation, and popups. `refractionOptions` accepts `strength` (default `3`), `thickness` in pixels (default `7`), `depth` (default `2` studs), `maxSurfaces` (default `32`), `assetBaseUrl`, and optional `templates` or `meshes`. Code and mesh files are fetched fresh on each run. The example's Appearance tab has transparency, blur, and refraction strength sliders. See [lens geometry notes](assets/liquid-glass/README.md) for the mesh build and rendering limits.

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

`CreateDock()` also starts empty. `AddTab()` returns a configurable dock item handle, `AddButton()` adds an action button, and `AddWindow()` / `AddPanel()` explicitly link windows. Custom module windows are added as dock items when their definitions load. No preset items are inserted. Create the optional Lua Modules panel separately when you want it:

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

The [example client](example.client.lua) loads the public library directly from GitHub with `loadstring` and demonstrates the source UI arrangement. Its callbacks are inert examples. It also adds a **Module Test** in the Lua Modules manager so you can try a custom module window, dock item, settings controls, actions, and enable/disable callbacks.

## Components

- Window with draggable title bar, tab navigation, visibility toggle, cursor release while open, cursor-state restoration on close, and theme overrides.
- Equal-width tabs, fill-height columns and sections, nested columns, source-style section tabs, scrollable sections, and collapsible configuration groups.
- Toggle, slider, single and multiselect dropdown, textbox, action button, label, divider, keybind, and HSV color picker with opacity.
- Source-style button-holder rows, multi-button rows, scrolling lists, output logs, hover tooltips, and notifications.
- Source-sized detached utility panels, a customizable draggable dock with icon buttons, pixel cursor, keybind list, watermark, and notifications. `dock:AddWindow()` links a panel or main window; `dock:AddTab()` and `dock:AddButton()` add custom actions. The dock starts without preset items; module windows are added when their definitions load.
- SVG icons are included in [`assets/icons`](assets/icons/). Original PNG icons and the glow image are in [`assets/roblox`](assets/roblox); the executor example downloads these through executor asset APIs.
- `control:Get()`, `control:Set(value)`, `control:SetVisible(bool)`, plus window-level `GetValues()` and `SetValues(values)` for application-owned configuration persistence.
- `menu:CreateWatermark(text)` returns a draggable watermark handle with `SetText`, `SetVisible`, `SetPosition`, `GetPosition`, and `Destroy`. It respects the Roblox topbar inset by default; pass `position`, `displayOrder`, or `ignoreGuiInset` in its options to customize placement.
- `menu:CreateLuaModuleManager(options)` creates an optional Lua module editor and manager. Each loaded module definition gets its own Backtrack-styled window and dock item; the manager's **Open** button opens that same window. A definition can use `Window` to customize its title, icon, size, position, and dock item, `Build(panel, module, menu, manager)` to add any library controls, and `Settings` to generate standard controls automatically. Supported setting types are `toggle`, `slider`, `dropdown`, `multidropdown`, `textbox`, `colorpicker`, `keybind`, `button`, and `label`. Definition sources are compiled when first enabled or run and require executor `loadstring` support. Legacy scripts that return no definition remain available as one-shot **Run** modules.

Example module source to paste into the editor:

```lua
local menu, manager, module = ...

return {
    Window = {
        title = "My Module",
        iconText = "M",
        dock = { order = 20 },
    },

    Build = function(panel, module, menu, manager)
        local actions = panel:AddSection("Actions")
        actions:Button({ name = "Say hello", callback = function()
            menu:Notify("Hello from my module", 3, "success")
        end })
    end,

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

The module context provides `Get(name)`, `Set(name, value, silent)`, `Notify(...)`, `Enable()`, `Disable()`, `IsEnabled()`, `OpenWindow()`, and `OpenSettings()` (`OpenSettings` is an alias). `OnEnable` and `OnDisable` receive `(module, menu, manager)`. A setting's `callback`/`onChanged` receives `(value, module, name)`; the module-level `OnSettingChanged` receives `(name, value, module)`. Color picker values use `{ color = Color3, alpha = number }`.

The manager API also exposes `AddModule(name, source, options)`, `GetModule(name)`, `GetModules()`, `LoadModule(name)`, `OpenModule(name)`, `OpenSettings(name)` (an alias), `EnableModule(name)`, `DisableModule(name)`, `SetModuleEnabled(name, bool)`, `RunModule(name)`, `RemoveModule(name)`, and `Destroy()`. Definitions can be registered directly without source text:

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
