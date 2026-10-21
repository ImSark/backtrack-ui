# Backtrack UI assets

This folder contains a small, original SVG icon set and the source menu's extracted color palette. The icons use a 24×24 view box, transparent background, rounded strokes, and `currentColor` so they can be recolored when inlined in a web page or edited in a vector editor.

The Lua library draws its controls with Roblox GUI primitives and does not need these files. Roblox `ImageLabel` does not load SVG files directly; convert an icon to PNG and upload it to Roblox if you want to use it there.

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

The referenced script loads separate PNG, MP3, and font files from the upstream [`backtrack-tech/backtrack.tech` repository](https://github.com/backtrack-tech/backtrack.tech). Those files are not required by this UI library and are not copied into this package. The source identifies their names and paths; see its [`storage`](https://github.com/backtrack-tech/backtrack.tech/tree/main/storage), [`fonts`](https://github.com/backtrack-tech/backtrack.tech/tree/main/fonts), [`hitmarkers`](https://github.com/backtrack-tech/backtrack.tech/tree/main/hitmarkers), and [`hitsounds`](https://github.com/backtrack-tech/backtrack.tech/tree/main/hitsounds) folders for the original files.
