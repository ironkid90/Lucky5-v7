import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const webRoot = path.resolve(__dirname, "..");
const cardDir = path.join(webRoot, "public", "assets", "lucky5", "cards");

const ranks = ["A", "K", "Q", "J", "10", "9", "8", "7", "6", "5", "4", "3", "2"];
const suits = [
  { code: "S", glyph: "♠", color: "#111111", label: "SPADE" },
  { code: "H", glyph: "♥", color: "#b51220", label: "HEART" },
  { code: "D", glyph: "♦", color: "#b51220", label: "DIAMOND" },
  { code: "C", glyph: "♣", color: "#111111", label: "CLUB" },
];

function escapeXml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function faceCardSvg(rank, suit) {
  const isFiveSpade = rank === "5" && suit.code === "S";
  const pips = rank === "A" ? 1 : Number.parseInt(rank, 10) || 2;
  const pipCount = Math.min(pips, 10);
  const pipRows = Array.from({ length: pipCount }, (_, index) => {
    const col = index % 2;
    const row = Math.floor(index / 2);
    const x = pipCount === 1 ? 50 : col === 0 ? 36 : 64;
    const y = pipCount === 1 ? 50 : 25 + row * 12;
    return `<text x="${x}" y="${y}" text-anchor="middle" dominant-baseline="middle" class="pip">${suit.glyph}</text>`;
  }).join("\n    ");

  const center = ["A", "K", "Q", "J"].includes(rank)
    ? `<text x="50" y="52" text-anchor="middle" dominant-baseline="middle" class="face">${escapeXml(rank)}</text>
    <text x="50" y="70" text-anchor="middle" dominant-baseline="middle" class="face-suit">${suit.glyph}</text>`
    : pipRows;

  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 150" role="img" aria-labelledby="title desc">
  <title id="title">Lucky5 ${escapeXml(rank)} ${escapeXml(suit.label)}</title>
  <desc id="desc">Original Lucky5 retro cabinet card face for ${escapeXml(rank)} of ${escapeXml(suit.label.toLowerCase())}s.</desc>
  <style>
    .rank,.suit,.pip,.face,.face-suit{fill:${suit.color};font-family:Lucky5Arcade,'Courier New',monospace;font-weight:700}
    .rank{font-size:${rank === "10" ? 15 : 19}px}.suit{font-size:18px}.pip{font-size:18px}.face{font-size:46px}.face-suit{font-size:25px}
    .micro{font-size:5px;fill:#8f5f1d;font-family:Lucky5Arcade,'Courier New',monospace;letter-spacing:.5px}
  </style>
  <rect x="2" y="2" width="96" height="146" rx="8" fill="#fff7df" stroke="#261607" stroke-width="3"/>
  <rect x="6" y="6" width="88" height="138" rx="5" fill="none" stroke="#d5a13d" stroke-width="1.5"/>
  <path d="M11 18h22M67 132h22" stroke="#f2c35e" stroke-width="2"/>
  <g>
    <text x="15" y="22" text-anchor="middle" class="rank">${escapeXml(rank)}</text>
    <text x="15" y="39" text-anchor="middle" class="suit">${suit.glyph}</text>
  </g>
  <g transform="rotate(180 50 75)">
    <text x="15" y="22" text-anchor="middle" class="rank">${escapeXml(rank)}</text>
    <text x="15" y="39" text-anchor="middle" class="suit">${suit.glyph}</text>
  </g>
  <g>${center}</g>
  ${isFiveSpade ? `<rect x="20" y="111" width="60" height="11" rx="2" fill="#ffe45c" stroke="#111" stroke-width="1"/>
  <text x="50" y="119" text-anchor="middle" class="micro" fill="#111">NEVER LOSE</text>` : ""}
</svg>
`;
}

function backSvg({ hold = false } = {}) {
  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 150" role="img" aria-labelledby="title desc">
  <title id="title">Lucky5 ${hold ? "hold" : "card"} back</title>
  <desc id="desc">Original Lucky5 Lebanese retro cabinet card back.</desc>
  <style>
    .label{font-family:Lucky5Arcade,'Courier New',monospace;font-weight:700;letter-spacing:1px}
  </style>
  <rect x="2" y="2" width="96" height="146" rx="8" fill="#0c1024" stroke="#261607" stroke-width="3"/>
  <rect x="7" y="7" width="86" height="136" rx="5" fill="#132d66" stroke="#f3c658" stroke-width="2"/>
  <path d="M16 19h68v112H16z" fill="#071331" stroke="#65d8ff" stroke-width="1.5"/>
  <path d="M18 21l64 108M82 21L18 129M50 22v106M20 75h60" stroke="#2456a4" stroke-width="3"/>
  <path d="M25 34h50v82H25z" fill="none" stroke="#ffdf54" stroke-width="2" stroke-dasharray="5 4"/>
  <text x="50" y="63" text-anchor="middle" class="label" font-size="14" fill="#ffdf54">LUCKY</text>
  <text x="50" y="83" text-anchor="middle" class="label" font-size="25" fill="#ffffff">5♠</text>
  <text x="50" y="102" text-anchor="middle" class="label" font-size="7" fill="#65d8ff">${hold ? "HOLD BACK" : "B SIDE"}</text>
</svg>
`;
}

await mkdir(cardDir, { recursive: true });
for (const rank of ranks) {
  for (const suit of suits) {
    await writeFile(path.join(cardDir, `${rank}${suit.code}.svg`), faceCardSvg(rank, suit), "utf8");
  }
}
await writeFile(path.join(cardDir, "bside.svg"), backSvg(), "utf8");
await writeFile(path.join(cardDir, "hold-bside.svg"), backSvg({ hold: true }), "utf8");

console.log(`Generated ${ranks.length * suits.length + 2} Lucky5 SVG card assets in ${cardDir}`);