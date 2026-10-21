# Backtrack UI

A standalone Luau UI library based on the reusable menu patterns in the [provided script](https://raw.githubusercontent.com/GLAMOHGA/Project-Delta/refs/heads/main/backtrack.tech.txt). The implementation is self-contained: it builds its own Roblox `ScreenGui`, uses built-in fonts and shapes, and does not download assets or include the source script's game behavior.

## Quick start

Place `backtrack_ui.lua` in a `ModuleScript`, then require it from a `LocalScript`:

```lua
local BacktrackUI = require(script.Parent.backtrack_ui)

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

## Components

- Window with draggable title bar, tab navigation, visibility toggle, and theme overrides.
- Tabs, flexible columns, sections, and collapsible configuration groups.
- Toggle, slider, single and multiselect dropdown, textbox, action button, label, divider, keybind, and HSV color picker with opacity.
- Multi-button rows, scrolling lists, output logs, hover tooltips, and notifications.
- Detached utility panels, draggable watermark, and notifications.
- Optional editable SVG icons are included in [`assets/icons`](assets/icons/). They are decorative companion assets and are not required by the Lua library.
- `control:Get()`, `control:Set(value)`, `control:SetVisible(bool)`, plus window-level `GetValues()` and `SetValues(values)` for application-owned configuration persistence.
- `menu:SetTheme({ accent = Color3.fromRGB(...) })` updates the current GUI palette.

Controls accept a `flag` and `callback`. Flags default to a generated name when omitted. A color picker returns `{ color = Color3, alpha = number }` from `Get()` and calls its callback with `(color, alpha)`. A keybind returns `{ key = EnumItem, mode = string, active = boolean }`.

## Builder-style aliases

The lowercase methods are available for compact builder code:

```lua
local menu = BacktrackUI:window({ name = "Example" })
local section = menu:tab({ name = "General" }):column():section({ name = "Settings" })
section:toggle({ name = "Enabled", flag = "enabled" })
```

The library intentionally leaves file/config storage, application state, and every control callback to the host script.

See [`assets/README.md`](assets/README.md) for the included icon pack and notes about using the upstream artwork.
