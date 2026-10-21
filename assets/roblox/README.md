# Roblox image assets

These PNGs are the small UI images referenced by the original script, from `backtrack-tech/backtrack.tech`'s `storage` folder. They are optional; the Lua library draws without them.

| File | Size | Use |
| --- | ---: | --- |
| `main.png` | 30×30 | Main dock icon |
| `style.png` | 30×30 | Style dock icon |
| `configurations.png` | 30×30 | Configurations dock icon |
| `playerlist.png` | 30×30 | Player list dock icon |
| `output.png` | 30×30 | Output dock icon |
| `glow4.png` | 100×100 | Sliced rose glow around windows and the dock |
| `logo.png` | 1920×1080 | Original splash artwork; not shown by the library |
| `pointer.png` | 14×14 | Original pointer artwork |
| `scroll.png` | 800×600 | Original scroll texture |
| `transparency.png` | 10×10 | Transparency checker texture |

The executor example downloads these PNGs to `backtrack_ui_assets` and passes them through executor `getcustomasset` or `getsynasset` APIs. The library also accepts asset IDs directly when a host already has them:

```lua
local menu = BacktrackUI.new({
    images = {
        main = "rbxassetid://YOUR_MAIN_ICON_ID",
        style = "rbxassetid://YOUR_STYLE_ICON_ID",
        configurations = "rbxassetid://YOUR_CONFIGURATIONS_ICON_ID",
        playerlist = "rbxassetid://YOUR_PLAYERLIST_ICON_ID",
        output = "rbxassetid://YOUR_OUTPUT_ICON_ID",
        glow4 = "rbxassetid://YOUR_GLOW_IMAGE_ID",
    },
})

menu:AddTab("General", "main")
menu:CreateDock()
```

Image assets are tinted with the library accent. The dock falls back to the tab's first letter when an icon ID is not supplied.
