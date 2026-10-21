# Backtrack UI assets

This folder contains an SVG icon set, a Roblox PNG set from the source menu, and its extracted color palette. The SVG icons use a 24×24 view box, transparent background, rounded strokes, and `currentColor` so they can be recolored when inlined in a web page or edited in a vector editor.

The Lua library draws its controls with Roblox GUI primitives. Roblox `ImageLabel` does not load SVG files directly; convert an icon to PNG before using it as an image asset.

## Included icons

`bell`, `check`, `chevron-down`, `chevron-right`, `close`, `copy`, `drag`, `expand`, `eye`, `eye-off`, `folder`, `image`, `info`, `menu`, `minus`, `output`, `palette`, `pin`, `plus`, `refresh`, `search`, `settings`, `sliders`, `success`, `users`, and `warning`.

The source color tokens are in [`theme.json`](theme.json). The source menu uses a near-black surface, muted grey text, and a rose accent.

## Use

For a web app, inline an icon and set its color with CSS:

```html
<svg class="icon" aria-hidden="true"><use href="assets/icons/check.svg#icon" /></svg>
```

```css
.icon { width: 20px; height: 20px; color: #ff627f; }
```

For a standalone `<img>`, `currentColor` defaults to black; set a stroke color in the SVG file or use the SVG as an inline element.

## Original source assets

The Roblox UI images are from the upstream [`backtrack-tech/backtrack.tech` storage folder](https://github.com/backtrack-tech/backtrack.tech/tree/main/storage) and are documented in [`roblox/README.md`](roblox/README.md). The executor example caches the dock icons, glow, scroll texture, and source Tahoma font using `writefile` and `getcustomasset` (or `getsynasset`), then applies the font as a Roblox `FontFace`. The UI library does not require sounds, hitmarkers, or hitsounds.
