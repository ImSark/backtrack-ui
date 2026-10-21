import { mkdir, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(fileURLToPath(import.meta.url));
const icons = {
  bell: '<path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9"/><path d="M10 21h4"/>',
  check: '<path d="m5 12 4.5 4.5L19 7"/>',
  "chevron-down": '<path d="m6 9 6 6 6-6"/>',
  "chevron-right": '<path d="m9 18 6-6-6-6"/>',
  close: '<path d="m18 6-12 12M6 6l12 12"/>',
  copy: '<rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 8V5a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h3"/>',
  drag: '<path d="M9 5h.01M15 5h.01M9 12h.01M15 12h.01M9 19h.01M15 19h.01" stroke-width="3"/>',
  expand: '<path d="M8 3H5a2 2 0 0 0-2 2v3m13-5h3a2 2 0 0 1 2 2v3M3 16v3a2 2 0 0 0 2 2h3m13-5v3a2 2 0 0 1-2 2h-3"/>',
  eye: '<path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6-10-6-10-6Z"/><circle cx="12" cy="12" r="2.5"/>',
  "eye-off": '<path d="m3 3 18 18M10.6 6.2A10.8 10.8 0 0 1 12 6c6.5 0 10 6 10 6a16 16 0 0 1-3 3.6M6.2 6.2C3.5 8 2 12 2 12s3.5 6 10 6c1.4 0 2.7-.3 3.8-.8"/><path d="M9.9 9.9a3 3 0 0 0 4.2 4.2"/>',
  folder: '<path d="M3 7a2 2 0 0 1 2-2h5l2 2h7a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7Z"/><path d="M3 10h18"/>',
  image: '<rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><path d="m21 15-5-5L5 21"/>',
  info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v5m0-8h.01"/>',
  menu: '<path d="M4 6h16M4 12h16M4 18h16"/>',
  minus: '<path d="M5 12h14"/>',
  output: '<path d="m8 9-4 3 4 3m8-6 4 3-4 3m-2-9-4 12"/>',
  palette: '<path d="M12 3a9 9 0 1 0 0 18h1.3a2 2 0 0 0 1.3-3.5 1.5 1.5 0 0 1 1-2.6H18a3 3 0 0 0 3-3c0-5-4-8.9-9-8.9Z"/><path d="M7.5 11h.01M10 7.5h.01M14.5 7.5h.01M17 11h.01" stroke-width="2.5"/>',
  pin: '<path d="m16 3 5 5-4 1-4 4-1 5-2-2-4 5 2-7-3-3 5-1 4-4 2-3Z"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  refresh: '<path d="M20 7v5h-5M4 17v-5h5"/><path d="M5.5 9a7 7 0 0 1 12-2L20 12M4 12l2.5 5a7 7 0 0 0 12-2"/>',
  search: '<circle cx="10.8" cy="10.8" r="6.8"/><path d="m16 16 5 5"/>',
  settings: '<path d="M12 8.5a3.5 3.5 0 1 0 0 7 3.5 3.5 0 0 0 0-7Z"/><path d="m19.4 15 .1.1 1.4 1.1-1.4 2.4-1.7-.7a8 8 0 0 1-1.8 1l-.3 1.8h-2.8l-.3-1.8a8 8 0 0 1-1.8-1l-1.7.7-1.4-2.4 1.4-1.1a7 7 0 0 1 0-2l-1.4-1.1 1.4-2.4 1.7.7a8 8 0 0 1 1.8-1l.3-1.8h2.8l.3 1.8a8 8 0 0 1 1.8 1l1.7-.7 1.4 2.4-1.4 1.1a7 7 0 0 1-.1 1.9Z" transform="translate(-2 -2)"/>',
  sliders: '<path d="M4 6h9m4 0h3M4 12h3m4 0h9M4 18h9m4 0h3"/><circle cx="15" cy="6" r="2"/><circle cx="9" cy="12" r="2"/><circle cx="15" cy="18" r="2"/>',
  success: '<circle cx="12" cy="12" r="9"/><path d="m8 12 2.5 2.5L16 9"/>',
  users: '<path d="M16 21v-2a4 4 0 0 0-4-4H7a4 4 0 0 0-4 4v2m17 0v-2a4 4 0 0 0-3-3.9M14 3.1a4 4 0 0 1 0 7.8"/><circle cx="9.5" cy="7" r="4"/>',
  warning: '<path d="M10.3 4.2 2.7 17.5A2 2 0 0 0 4.4 20h15.2a2 2 0 0 0 1.7-2.5L13.7 4.2a2 2 0 0 0-3.4 0Z"/><path d="M12 9v4m0 3h.01"/>',
};

await mkdir(join(root, "icons"), { recursive: true });
for (const [name, content] of Object.entries(icons)) {
  const svg = `<?xml version="1.0" encoding="UTF-8"?>\n<svg id="icon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" role="img" aria-labelledby="title">\n  <title id="title">${name.replaceAll("-", " ")}</title>\n  ${content}\n</svg>\n`;
  await writeFile(join(root, "icons", `${name}.svg`), svg, "utf8");
}

const manifest = {
  name: "Backtrack UI Icons",
  format: "SVG",
  viewBox: "0 0 24 24",
  defaultStroke: "currentColor",
  icons: Object.keys(icons),
};
await writeFile(join(root, "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`, "utf8");
