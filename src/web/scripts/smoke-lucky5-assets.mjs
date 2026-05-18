import { access, readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const webRoot = path.resolve(__dirname, "..");
const repoRoot = path.resolve(webRoot, "..", "..");
const cardDir = path.join(webRoot, "public", "assets", "lucky5", "cards");
const componentPath = path.join(webRoot, "components", "lucky5-cabinet.tsx");
const cssPath = path.join(webRoot, "app", "globals.css");
const specPath = path.join(repoRoot, "docs", "assets", "lucky5-cabinet-assets.md");

const ranks = ["A", "K", "Q", "J", "10", "9", "8", "7", "6", "5", "4", "3", "2"];
const suits = ["S", "H", "D", "C"];
const requiredCards = ranks.flatMap((rank) => suits.map((suit) => `${rank}${suit}.svg`));
requiredCards.push("bside.svg", "hold-bside.svg");

async function assertFile(filePath) {
  try {
    await access(filePath);
  } catch {
    throw new Error(`Missing required asset file: ${filePath}`);
  }
}

for (const fileName of requiredCards) {
  await assertFile(path.join(cardDir, fileName));
}

const component = await readFile(componentPath, "utf8");
const css = await readFile(cssPath, "utf8");
const spec = await readFile(specPath, "utf8");

for (const needle of [
  'return `${LUCKY5_CARD_ASSET_ROOT}/${code}.svg`;',
  'src={LUCKY5_CARD_BACK_SRC}',
  "zero-based index 2",
]) {
  if (!component.includes(needle)) {
    throw new Error(`Cabinet component is missing expected asset integration marker: ${needle}`);
  }
}

for (const selector of [
  ".apk-btn-big",
  ".apk-btn-small",
  ".apk-btn-cancel",
  ".apk-btn-deal",
  ".apk-btn-bet",
  ".apk-btn-take-half",
  ".apk-btn-take-score",
  ".apk-menu-btn-label",
  ".apk-hold-btn",
  ".apk-btn:active:not(:disabled)",
]) {
  if (!css.includes(selector)) {
    throw new Error(`Cabinet CSS is missing expected button asset/state selector: ${selector}`);
  }
}

for (const text of ["52-card deck", "bside.svg", "Button normal/pressed states", "Godot"]) {
  if (!spec.includes(text)) {
    throw new Error(`Asset spec is missing expected handoff text: ${text}`);
  }
}

console.log(`Lucky5 asset smoke passed: ${requiredCards.length} card/back SVGs plus cabinet CSS/spec integration verified.`);