# Backtrack UI

A standalone Luau UI library based on the menu in the [provided script](https://raw.githubusercontent.com/GLAMOHGA/Project-Delta/refs/heads/main/backtrack.tech.txt). The example reproduces the original `Combat`, `Players`, `Misc`, and `Visuals` tabs and adds `Config`, `Theme`, and `Console` tabs with matching dock shortcuts, demo profile controls, live theme presets and color pickers, and a scrollable console. It also keeps the 604×631 window, square outlines, rose accent, dark blue-grey gradient, compact controls, and dock.

The library only builds interface elements and invokes callbacks supplied by the host script. It does not include the source script's game behavior. The executor example uses `loadstring(game:HttpGet(...))`; its runtime cache-buster requests fresh example and library code each run. It caches the PNG UI images and original Tahoma font under `backtrack_ui_assets`, using executor file APIs. A custom `FontFace` can also be supplied as `theme.fontFace`.

## Executor loader

Use this same command each time. The unique query string fetches fresh example and library code from `main`; image and font assets are cached locally by the example:

```lua
local url = "https://raw.githubusercontent.com/ImSark/backtrack-ui/main/example.client.lua"
local cacheBuster = tostring(math.floor(os.clock() * 1000000))
loadstring(game:HttpGet(url .. "?t=" .. cacheBuster))()
```

## Library API

The executor example above handles asset loading and opens the full demo. For a custom executor menu, load the library first:

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

When no `parent` is supplied, `BacktrackUI.new` parents the menu to the local player's `PlayerGui`. Pass `parent` to host the GUI elsewhere. `toggleKey` accepts a Roblox `Enum.KeyCode`.

The [example client](example.client.lua) loads the public library directly from GitHub with `loadstring` and demonstrates the source UI arrangement. Its callbacks are inert examples.

## Components

- Window with draggable title bar, tab navigation, visibility toggle, cursor release while open, cursor-state restoration on close, and theme overrides.
- Equal-width tabs, fill-height columns and sections, nested columns, source-style section tabs, scrollable sections, and collapsible configuration groups.
- Toggle, slider, single and multiselect dropdown, textbox, action button, label, divider, keybind, and HSV color picker with opacity.
- Source-style button-holder rows, multi-button rows, scrolling lists, output logs, hover tooltips, and notifications.
- Source-sized detached utility panels, a draggable navigation dock with square icon buttons and open-state indicators, watermark, and notifications. Dock buttons toggle independent panels; each panel can also be closed from its title bar.
- SVG icons are included in [`assets/icons`](assets/icons/). Original PNG icons and the glow image are in [`assets/roblox`](assets/roblox); the executor example downloads these through executor asset APIs.
- `control:Get()`, `control:Set(value)`, `control:SetVisible(bool)`, plus window-level `GetValues()` and `SetValues(values)` for application-owned configuration persistence.
- `menu:SetTheme({ accent = Color3.fromRGB(...) })` updates the current GUI palette.

Controls accept a `flag` and `callback`. Flags default to a generated name when omitted. A color picker returns `{ color = Color3, alpha = number }` from `Get()` and calls its callback with `(color, alpha)`. A keybind returns `{ key = EnumItem, mode = string, active = boolean }`.

## Builder-style aliases

`Column:MultiSection({ names = { ... } })` returns one section object per name. Each section is selected by its inline tab; a section exposes `SetActive()` through its `MultiSection` field. `Column:Column()` creates a nested fill-height column, and detached panels support `panel:AddColumn()`.

`Section:ButtonHolder()` starts a horizontal action row. Following `Section:Button()` calls are placed in that row until another button holder is created. Use `Section:MultiButton()` when the buttons should stay inside a single labeled row.

The lowercase methods are available for compact builder code:

```lua
local menu = BacktrackUI:window({ name = "Example" })
local section = menu:tab({ name = "General" }):column():section({ name = "Settings" })
section:toggle({ name = "Enabled", flag = "enabled" })
```

The library intentionally leaves file/config storage, application state, and every control callback to the host script.

See [`assets/README.md`](assets/README.md) for the icon pack, source PNGs, and notes about uploading image assets to Roblox.
