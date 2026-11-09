// Minimal GitHub stats cards (terminal style) - GitHub REST API only, no dependencies
import { writeFileSync, mkdirSync } from "node:fs";

const USER = process.env.GH_USER || "jasurlive";
const TOKEN = process.env.GITHUB_TOKEN;

const api = async (path) => {
  const res = await fetch(`https://api.github.com${path}`, {
    headers: {
      "User-Agent": "stats-card",
      Accept: "application/vnd.github+json",
      ...(TOKEN && { Authorization: `Bearer ${TOKEN}` }),
    },
  });
  if (!res.ok) throw new Error(`${res.status} ${path}`);
  return res.json();
};
const count = async (q) => (await api(`/search/${q}`)).total_count;

// ---------- data ----------
const repos = [];
for (let page = 1; ; page++) {
  const batch = await api(
    `/users/${USER}/repos?per_page=100&type=owner&page=${page}`
  );
  repos.push(...batch.filter((r) => !r.fork));
  if (batch.length < 100) break;
}

const rows = [
  ["Total stars", repos.reduce((sum, r) => sum + r.stargazers_count, 0)],
  ["Commits", await count(`commits?q=author:${USER}`)],
  ["Pull requests", await count(`issues?q=author:${USER}+type:pr`)],
  ["Issues", await count(`issues?q=author:${USER}+type:issue`)],
];

const langCount = {};
for (const { language } of repos)
  if (language) langCount[language] = (langCount[language] || 0) + 1;
const langs = Object.entries(langCount)
  .sort((a, b) => b[1] - a[1])
  .slice(0, 6)
  .map(([lang]) => lang);

// ---------- style ----------
const C = {
  bg: "#0d1117",
  border: "#30363d",
  text: "#c9d1d9",
  muted: "#8b949e",
  prompt: "#3fb950",
};

// GitHub's official language colors (github/linguist)
const LANG_COLORS = {
  JavaScript: "#f1e05a",
  TypeScript: "#3178c6",
  Python: "#3572A5",
  HTML: "#e34c26",
  CSS: "#663399",
  SCSS: "#c6538c",
  "Jupyter Notebook": "#DA5B0B",
  Java: "#b07219",
  C: "#555555",
  "C++": "#f34b7d",
  "C#": "#178600",
  Go: "#00ADD8",
  Rust: "#dea584",
  PHP: "#4F5D95",
  Ruby: "#701516",
  Swift: "#F05138",
  Kotlin: "#A97BFF",
  Dart: "#00B4AB",
  Shell: "#89e051",
  Vue: "#41b883",
  Svelte: "#ff3e00",
  Lua: "#000080",
  R: "#198CE7",
  Dockerfile: "#384d54",
  Astro: "#ff5a03",
  Solidity: "#AA6746",
};

const esc = (s) =>
  String(s).replace(
    /[&<>"]/g,
    (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c])
  );

// shared size: both cards grow to fit the longer one
const W = 300;
const LINE_Y = (i) => 64 + i * 22;
const H = 60 + Math.max(rows.length, langs.length) * 22;

const card = (cmd, body) => `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
<style>text{font:13px ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}</style>
<rect x="0.5" y="0.5" width="${W - 1}" height="${H - 1}" rx="8" fill="${C.bg}" stroke="${C.border}"/>
<text x="20" y="34" fill="${C.prompt}">${esc(USER)}@framework ❯ <tspan fill="${C.text}">cat ${cmd}.md</tspan></text>
${body}
</svg>`;

// ---------- cards ----------
// language-share chart drawn right of the language list (shares by repo count)
// CHART: "pie" | "donut" | "bars" | "waffle"
const CHART = process.env.CHART || "bars";
const chart = (() => {
  const slices = Object.entries(langCount).sort((a, b) => b[1] - a[1]);
  const top = slices.slice(0, 6);
  const rest = slices.slice(6).reduce((s, [, n]) => s + n, 0);
  if (rest) top.push(["Other", rest]);
  const total = top.reduce((s, [, n]) => s + n, 0);
  if (!total) return "";
  const color = (lang) => LANG_COLORS[lang] || C.muted;
  const cx = 236, cy = (64 + LINE_Y(langs.length - 1)) / 2 - 4;

  if (CHART === "donut") {
    // each slice is a dashed segment of one ring, starting at 12 o'clock
    const r = 36, len = 2 * Math.PI * r;
    let off = 0;
    return top
      .map(([lang, n]) => {
        const seg = (n / total) * len;
        const el = `<circle cx="${cx}" cy="${cy}" r="${r}" fill="none" stroke="${color(lang)}" stroke-width="14" stroke-dasharray="${seg.toFixed(2)} ${len.toFixed(2)}" stroke-dashoffset="${(-off).toFixed(2)}" transform="rotate(-90 ${cx} ${cy})"/>`;
        off += seg;
        return el;
      })
      .join("\n");
  }

  if (CHART === "bars") {
    // one bar per listed language, on its own row, scaled to the largest
    const max = langCount[langs[0]];
    return langs
      .map((lang, i) => {
        const w = Math.max(4, (langCount[lang] / max) * 100);
        return `<rect x="180" y="${LINE_Y(i) - 9}" width="${w.toFixed(1)}" height="10" rx="5" fill="${color(lang)}"/>`;
      })
      .join("\n");
  }

  if (CHART === "waffle") {
    // 10x10 grid, one cell = 1% (largest-remainder rounding so it sums to 100)
    const raw = top.map(([, n]) => (n / total) * 100);
    const cells = raw.map(Math.floor);
    raw
      .map((v, i) => [v - cells[i], i])
      .sort((a, b) => b[0] - a[0])
      .slice(0, 100 - cells.reduce((a, b) => a + b, 0))
      .forEach(([, i]) => cells[i]++);
    const fills = top.flatMap(([lang], i) => Array(cells[i]).fill(color(lang)));
    const S = 8, G = 2, x0 = cx - 49, y0 = cy - 49;
    return fills
      .map((f, k) => `<rect x="${x0 + (k % 10) * (S + G)}" y="${y0 + Math.floor(k / 10) * (S + G)}" width="${S}" height="${S}" rx="2" fill="${f}"/>`)
      .join("\n");
  }

  // pie
  const r = 44;
  if (top.length === 1) return `<circle cx="${cx}" cy="${cy}" r="${r}" fill="${color(top[0][0])}"/>`;
  let a = -Math.PI / 2;
  const pt = (t) => `${(cx + r * Math.cos(t)).toFixed(2)},${(cy + r * Math.sin(t)).toFixed(2)}`;
  return top
    .map(([lang, n]) => {
      const b = a + (n / total) * 2 * Math.PI;
      const d = `M${cx},${cy} L${pt(a)} A${r},${r} 0 ${b - a > Math.PI ? 1 : 0} 1 ${pt(b)} Z`;
      a = b;
      return `<path d="${d}" fill="${color(lang)}"/>`;
    })
    .join("\n");
})();

const statsBody = rows
  .map(
    ([label, value], i) =>
      `<text x="20" y="${LINE_Y(i)}" fill="${C.muted}">${label}</text>` +
      `<text x="280" y="${LINE_Y(i)}" fill="${C.text}" text-anchor="end">${value.toLocaleString("en-US")}</text>`
  )
  .join("\n");

const langsBody = langs
  .map(
    (lang, i) =>
      `<circle cx="25" cy="${LINE_Y(i) - 4}" r="5" fill="${LANG_COLORS[lang] || C.muted}"/>` +
      `<text x="40" y="${LINE_Y(i)}" fill="${C.text}">${esc(lang)}</text>`
  )
  .join("\n") + "\n" + chart;

// ---------- typing banner (CSS only, plays once) ----------
const CODE = `console.log("the secret to success: start, then give up, then blame the universe");`;
const N = CODE.length + 2; // + "❯ " prefix
const TW = N * 8.4; // text width, 8.4px per char at 14px monospace
const DUR = N * 0.05;

const typing = `<svg xmlns="http://www.w3.org/2000/svg" width="${TW + 40}" height="44" viewBox="0 0 ${TW + 40} 44">
<style>
text{font:14px ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}
.type{animation:slide ${DUR}s steps(${N}) .5s both}
.cursor{animation:slide ${DUR}s steps(${N}) .5s both,blink 1s step-end ${DUR + 0.5}s infinite}
@keyframes slide{to{transform:translateX(${TW}px)}}
@keyframes blink{50%{opacity:0}}
</style>
<rect x="0.5" y="0.5" width="${TW + 39}" height="43" rx="8" fill="${C.bg}"/>
<text x="20" y="27" textLength="${TW}" fill="${C.text}"><tspan fill="${C.prompt}">❯ </tspan>${esc(CODE)}</text>
<rect class="type" x="20" y="10" width="${TW}" height="24" fill="${C.bg}"/>
<rect class="cursor" x="20" y="15" width="8" height="16" fill="${C.prompt}"/>
<rect x="0.5" y="0.5" width="${TW + 39}" height="43" rx="8" fill="none" stroke="${C.border}"/>
</svg>`;

// ---------- write ----------
mkdirSync("stats", { recursive: true });
writeFileSync("stats/stats.svg", card("stats", statsBody));
writeFileSync("stats/langs.svg", card("langs", langsBody));
writeFileSync("stats/typing.svg", typing);
console.log(Object.fromEntries(rows), langs);
