// Minimal GitHub stats cards - GitHub REST API only, no dependencies
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
const user = await api(`/users/${USER}`);

const repos = [];
for (let page = 1; ; page++) {
  const batch = await api(
    `/users/${USER}/repos?visibility=all&affiliation=owner&per_page=100&page=${page}`
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
  .slice(0, 6);

// ---------- style ----------
const C = {
  bg: "#0d1117",
  border: "#30363d",
  title: "#58a6ff",
  text: "#c9d1d9",
  muted: "#8b949e",
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
const color = (lang) => LANG_COLORS[lang] || C.muted;

const esc = (s) =>
  String(s).replace(
    /[&<>"]/g,
    (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c])
  );

const card = (
  w,
  h,
  title,
  body
) => `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">
<style>text{font-family:-apple-system,Segoe UI,Helvetica,Arial,sans-serif}</style>
<rect x="0.5" y="0.5" width="${w - 1}" height="${h - 1}" rx="8" fill="${
  C.bg
}" stroke="${C.border}"/>
<text x="20" y="32" font-size="16" font-weight="600" fill="${C.title}">${esc(
  title
)}</text>
${body}
</svg>`;

// ---------- stats card ----------
const statsBody = rows
  .map(([label, value], i) => {
    const y = 62 + i * 22;
    return (
      `<text x="20" y="${y}" font-size="13" fill="${C.muted}">${label}</text>` +
      `<text x="280" y="${y}" font-size="13" font-weight="600" fill="${
        C.text
      }" text-anchor="end">${value.toLocaleString("en-US")}</text>`
    );
  })
  .join("\n");

// ---------- languages card ----------
const total = langs.reduce((sum, [, n]) => sum + n, 0) || 1;
let x = 20;
const bar = langs
  .map(([lang, n]) => {
    const w = (n / total) * 260;
    const seg = `<rect x="${x}" y="48" width="${w}" height="8" fill="${color(
      lang
    )}"/>`;
    x += w;
    return seg;
  })
  .join("");

const legend = langs
  .map(([lang, n], i) => {
    const cx = 20 + (i % 2) * 135;
    const cy = 80 + Math.floor(i / 2) * 22;
    return (
      `<circle cx="${cx + 5}" cy="${cy - 4}" r="5" fill="${color(lang)}"/>` +
      `<text x="${cx + 16}" y="${cy}" font-size="12" fill="${C.text}">${esc(
        lang
      )} <tspan fill="${C.muted}">${n}</tspan></text>`
    );
  })
  .join("\n");

const langsBody =
  `<clipPath id="r"><rect x="20" y="48" width="260" height="8" rx="4"/></clipPath>` +
  `<g clip-path="url(#r)">${bar}</g>\n${legend}`;

// ---------- write ----------
mkdirSync("stats", { recursive: true });
writeFileSync(
  "stats/stats.svg",
  card(
    300,
    62 + rows.length * 22,
    `${user.name || USER}'s github stats`,
    statsBody
  )
);
writeFileSync(
  "stats/langs.svg",
  card(
    300,
    80 + Math.ceil(langs.length / 2) * 22,
    "Repos per language",
    langsBody
  )
);
console.log(Object.fromEntries(rows), langs);
