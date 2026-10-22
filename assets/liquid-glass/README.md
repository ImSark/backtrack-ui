# Lens geometry

These are original, procedurally generated meshes for `liquid_glass_renderer.lua`. The DevForum resource at <https://devforum.roblox.com/t/4416219> inspired the camera-aligned glass technique. No code or meshes from its restricted attachment are included.

Run `node assets/liquid-glass/build-lenses.mjs` from the repository root to rebuild them. The generator checks triangle indices, winding, normals, and unit bounds before writing Roblox FileMesh version 2 files and `manifest.json` with SHA-256 hashes.

The flat center, quarter-cylinder edge, and quarter-sphere corner patches join into a rounded lens. Nine patches preserve the corner radius when the window changes size; a pill uses six active patches. One Highlight groups each lens, and the patches use Roblox's Glass material. The renderer repositions existing parts on `RenderStepped`; it only updates their sizes when the GUI dimensions, corner radius, camera scale, or thickness change.

The executor needs `writefile`, `getcustomasset` (or `getsynasset`), and permission to import MeshParts through AssetService or InsertService. Each renderer writes fresh files with unique names and removes them on destruction when `delfile` is available. There is no executable code in the mesh files. Alternatively, callers can supply their own `refractionOptions.templates` (MeshParts) or `refractionOptions.meshes` (mesh URIs).

Refraction affects the 3D world behind the UI. It does not distort other ScreenGui content or provide a screen capture. Roblox's graphics settings and platform determine whether Glass refraction renders; mobile does not support it. A partially clipped lens is hidden to avoid drawing outside a scroller; its ordinary UI surface remains visible. At most 32 lens surfaces are registered by default; `maxSurfaces` can change this budget.
