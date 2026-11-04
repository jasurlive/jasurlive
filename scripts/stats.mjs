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
const LINE_Y = (i) => 80 + i * 22;
const H = 70 + Math.max(rows.length, langs.length) * 22;

const card = (cmd, body) => `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
<style>text{font:13px ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}</style>
<rect x="0.5" y="0.5" width="${W - 1}" height="${H - 1}" rx="8" fill="${C.bg}" stroke="${C.border}"/>

<text x="20" y="52" fill="${C.prompt}">jasur@framework ❯ <tspan fill="${C.text}">cat ${cmd}.md</tspan></text>
${body}
</svg>`;

// ---------- cards ----------
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
  .join("\n");

// ---------- write ----------
mkdirSync("stats", { recursive: true });
writeFileSync("stats/stats.svg", card("stats", statsBody));
writeFileSync("stats/langs.svg", card("langs", langsBody));
console.log(Object.fromEntries(rows), langs);
