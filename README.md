# Backtrack UI

A standalone Luau UI library based on the menu in the [provided script](https://raw.githubusercontent.com/GLAMOHGA/Project-Delta/refs/heads/main/backtrack.tech.txt). The example uses the original `Combat`, `Players`, `Misc`, and `Visuals` tabs and recreates the 604×631 window with its square nested outlines, rose accent, dark blue-grey gradient, compact controls, dock, and source-sized companion panels.

The library only builds interface elements and invokes callbacks supplied by the host script. It does not include the source script's game behavior. The example uses `loadstring(game:HttpGet(...))` and, when executor file APIs are available, downloads the original PNG icons and glow into a local asset cache with `getcustomasset` or `getsynasset`. In Roblox Studio, upload the PNGs in [`assets/roblox`](assets/roblox) and pass their asset IDs in `options.images`. Roblox does not expose the source's downloaded Tahoma font as a built-in font, so the library uses `Enum.Font.Legacy` as its compact fallback.

## Quick start

In Roblox Studio, place `backtrack_ui.lua` in a `ModuleScript`, then require it from a `LocalScript`:

```lua
local BacktrackUI = require(script.Parent.backtrack_ui)

local menu = BacktrackUI.new({
    title = "Example Menu",
    toggleKey = Enum.KeyCode.RightShift,
    images = {
        -- After uploading the PNG files, add entries such as:
        -- main = "rbxassetid://YOUR_MAIN_ICON_ID",
        -- glow4 = "rbxassetid://YOUR_GLOW_IMAGE_ID",
    },
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

- Window with draggable title bar, tab navigation, visibility toggle, and theme overrides.
- Tabs, flexible columns, sections, and collapsible configuration groups.
- Toggle, slider, single and multiselect dropdown, textbox, action button, label, divider, keybind, and HSV color picker with opacity.
- Multi-button rows, scrolling lists, output logs, hover tooltips, and notifications.
- Source-sized detached utility panels, a draggable 157×39 navigation dock, watermark, and notifications.
- SVG icons are included in [`assets/icons`](assets/icons/). Original PNG icons and the glow image are in [`assets/roblox`](assets/roblox). Roblox Studio users can upload them and pass their `rbxassetid://...` values in `options.images`; the executor example loads them from the public repo when local asset APIs are available.
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

See [`assets/README.md`](assets/README.md) for the icon pack, source PNGs, and notes about uploading image assets to Roblox.
