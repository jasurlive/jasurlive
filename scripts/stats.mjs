// Minimal GitHub stats cards \u2014 uses only GitHub's REST API, no dependencies
import { writeFileSync, mkdirSync } from "node:fs";

const USER = process.env.GH_USER || "jasurlive";
const TOKEN = process.env.GITHUB_TOKEN;
const headers = {
  "User-Agent": "stats-card",
  Accept: "application/vnd.github+json",
  ...(TOKEN && { Authorization: `Bearer ${TOKEN}` }),
};
const api = async (path) => {
  const r = await fetch(`https://api.github.com${path}`, { headers });
  if (!r.ok) throw new Error(`${r.status} ${path}`);
  return r.json();
};

// --- fetch data ---
const user = await api(`/users/${USER}`);
let repos = [];
for (let page = 1; ; page++) {
  const batch = await api(
    `/users/${USER}/repos?per_page=100&type=owner&page=${page}`
  );
  repos.push(...batch);
  if (batch.length < 100) break;
}
repos = repos.filter((r) => !r.fork);

const stars = repos.reduce((s, r) => s + r.stargazers_count, 0);
const forks = repos.reduce((s, r) => s + r.forks_count, 0);
const prs = (await api(`/search/issues?q=author:${USER}+type:pr`)).total_count;
const issues = (await api(`/search/issues?q=author:${USER}+type:issue`))
  .total_count;
const commits = (await api(`/search/commits?q=author:${USER}`)).total_count;

const langCount = {};
for (const r of repos)
  if (r.language) langCount[r.language] = (langCount[r.language] || 0) + 1;
const langs = Object.entries(langCount)
  .sort((a, b) => b[1] - a[1])
  .slice(0, 6);

// --- draw SVGs ---
const C = {
  bg: "#0d1117",
  border: "#30363d",
  title: "#58a6ff",
  text: "#c9d1d9",
  muted: "#8b949e",
};
const PALETTE = [
  "#58a6ff",
  "#3fb950",
  "#d29922",
  "#f778ba",
  "#a371f7",
  "#ff7b72",
];
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
${body}</svg>`;

const rows = [
  ["Total stars", stars],
  ["Total forks", forks],
  ["Commits", commits],
  ["Pull requests", prs],
  ["Issues", issues],
  ["Public repos", user.public_repos],
  ["Followers", user.followers],
];
const statsBody = rows
  .map(
    ([k, v], i) =>
      `<text x="20" y="${62 + i * 22}" font-size="13" fill="${
        C.muted
      }">${k}</text>` +
      `<text x="280" y="${
        62 + i * 22
      }" font-size="13" font-weight="600" fill="${
        C.text
      }" text-anchor="end">${v.toLocaleString("en-US")}</text>`
  )
  .join("\n");

const total = langs.reduce((s, [, n]) => s + n, 0) || 1;
let x = 20;
const bar = langs
  .map(([, n], i) => {
    const w = (n / total) * 260,
      seg = `<rect x="${x}" y="48" width="${w}" height="8" fill="${PALETTE[i]}"/>`;
    x += w;
    return seg;
  })
  .join("");
const legend = langs
  .map(([l, n], i) => {
    const cx = 20 + (i % 2) * 135,
      cy = 80 + Math.floor(i / 2) * 22;
    return (
      `<circle cx="${cx + 5}" cy="${cy - 4}" r="5" fill="${PALETTE[i]}"/>` +
      `<text x="${cx + 16}" y="${cy}" font-size="12" fill="${C.text}">${esc(
        l
      )} <tspan fill="${C.muted}">${n}</tspan></text>`
    );
  })
  .join("\n");
const langBody = `<clipPath id="r"><rect x="20" y="48" width="260" height="8" rx="4"/></clipPath><g clip-path="url(#r)">${bar}</g>\n${legend}`;

mkdirSync("stats", { recursive: true });
writeFileSync(
  "stats/stats.svg",
  card(
    300,
    62 + rows.length * 22,
    `${user.name || USER}'s GitHub Stats`,
    statsBody
  )
);
writeFileSync(
  "stats/langs.svg",
  card(
    300,
    80 + Math.ceil(langs.length / 2) * 22,
    "Repos per language",
    langBody
  )
);
console.log({ stars, forks, commits, prs, issues, langs });
