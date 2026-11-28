#!/usr/bin/env bash
# Minimal GitHub stats cards (terminal style) - GitHub REST API, curl + jq only
set -euo pipefail

USER="${GH_USER:-jasurlive}"

api() {
  curl -fsS -H "User-Agent: stats-card" -H "Accept: application/vnd.github+json" \
    ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} "https://api.github.com$1"
}
count() { api "/search/$1" | jq .total_count; }
commas() { sed ':a;s/\B[0-9]\{3\}\>/,&/;ta' <<<"$1"; }
esc() { sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g' <<<"$1"; }

# ---------- data ----------
repos="[]"
for ((page = 1; ; page++)); do
  batch=$(api "/users/$USER/repos?per_page=100&type=owner&page=$page")
  repos=$(jq -s '.[0] + [.[1][] | select(.fork | not)]' <<<"$repos $batch")
  (($(jq length <<<"$batch") < 100)) && break
done

labels=("Total stars" "Commits" "Pull requests" "Issues")
values=(
  "$(jq 'map(.stargazers_count) | add // 0' <<<"$repos")"
  "$(count "commits?q=author:$USER")"
  "$(count "issues?q=author:$USER+type:pr")"
  "$(count "issues?q=author:$USER+type:issue")"
)

# top 6 languages by repo count, ties -> most recently pushed first ("count<TAB>language")
mapfile -t langs < <(jq -r 'map(select(.language)) | group_by(.language)
  | map([length, .[0].language, (map(.pushed_at) | max)])
  | sort_by(.[2]) | reverse | sort_by(-.[0]) | .[:6][] | .[:2] | @tsv' <<<"$repos")

# ---------- style ----------
BG="#0d1117" BORDER="#30363d" TEXT="#c9d1d9" MUTED="#8b949e" PROMPT="#3fb950"

# GitHub's official language colors (github/linguist)
declare -A LANG_COLORS=(
  [JavaScript]="#f1e05a" [TypeScript]="#3178c6" [Python]="#3572A5" [HTML]="#e34c26"
  [CSS]="#663399" [SCSS]="#c6538c" ["Jupyter Notebook"]="#DA5B0B" [Java]="#b07219"
  [C]="#555555" ["C++"]="#f34b7d" ["C#"]="#178600" [Go]="#00ADD8" [Rust]="#dea584"
  [PHP]="#4F5D95" [Ruby]="#701516" [Swift]="#F05138" [Kotlin]="#A97BFF" [Dart]="#00B4AB"
  [Shell]="#89e051" [Vue]="#41b883" [Svelte]="#ff3e00" [Lua]="#000080" [R]="#198CE7"
  [Dockerfile]="#384d54" [Astro]="#ff5a03" [Solidity]="#AA6746"
)

# shared size: both cards grow to fit the longer one
W=300
line_y() { echo $((64 + $1 * 22)); }
rows=$((${#labels[@]} > ${#langs[@]} ? ${#labels[@]} : ${#langs[@]}))
H=$((60 + rows * 22))

card() { # $1 = command name, $2 = body
  cat <<EOF
<svg xmlns="http://www.w3.org/2000/svg" width="$W" height="$H" viewBox="0 0 $W $H">
<style>text{font:13px ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}</style>
<rect x="0.5" y="0.5" width="$((W - 1))" height="$((H - 1))" rx="8" fill="$BG" stroke="$BORDER"/>
<text x="20" y="34" fill="$PROMPT">$(esc "$USER")@framework ❯ <tspan fill="$TEXT">cat $1.md</tspan></text>
$2
</svg>
EOF
}

# ---------- cards ----------
stats_body=""
for i in "${!labels[@]}"; do
  y=$(line_y "$i")
  stats_body+="<text x=\"20\" y=\"$y\" fill=\"$MUTED\">${labels[i]}</text><text x=\"280\" y=\"$y\" fill=\"$TEXT\" text-anchor=\"end\">$(commas "${values[i]}")</text>"$'\n'
done

# language list + one bar per language, scaled to the largest
langs_body=""
max=${langs[0]%%$'\t'*}
for i in "${!langs[@]}"; do
  n=${langs[i]%%$'\t'*} lang=${langs[i]#*$'\t'}
  y=$(line_y "$i") color=${LANG_COLORS[$lang]:-$MUTED}
  bar=$((n * 100 / max > 4 ? n * 100 / max : 4))
  langs_body+="<circle cx=\"25\" cy=\"$((y - 4))\" r=\"5\" fill=\"$color\"/><text x=\"40\" y=\"$y\" fill=\"$TEXT\">$(esc "$lang")</text>"$'\n'
  langs_body+="<rect x=\"180\" y=\"$((y - 9))\" width=\"$bar\" height=\"10\" rx=\"5\" fill=\"$color\"/>"$'\n'
done

# ---------- typing banner (CSS only, plays once) ----------
CODE='console.log("the secret to success: start, then give up, then blame the universe");'
N=$((${#CODE} + 2))                                  # + "❯ " prefix
TW=$(awk "BEGIN{print $N * 8.4}")                    # 8.4px per char at 14px monospace
DUR=$(awk "BEGIN{print $N * 0.05}")
typing=$(cat <<EOF
<svg xmlns="http://www.w3.org/2000/svg" width="$(awk "BEGIN{print $TW + 40}")" height="44" viewBox="0 0 $(awk "BEGIN{print $TW + 40}") 44">
<style>
text{font:14px ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}
.type{animation:slide ${DUR}s steps($N) .5s both}
.cursor{animation:slide ${DUR}s steps($N) .5s both,blink 1s step-end $(awk "BEGIN{print $DUR + 0.5}")s infinite}
@keyframes slide{to{transform:translateX(${TW}px)}}
@keyframes blink{50%{opacity:0}}
</style>
<rect x="0.5" y="0.5" width="$(awk "BEGIN{print $TW + 39}")" height="43" rx="8" fill="$BG"/>
<text x="20" y="27" textLength="$TW" fill="$TEXT"><tspan fill="$PROMPT">❯ </tspan>$(esc "$CODE")</text>
<rect class="type" x="20" y="10" width="$TW" height="24" fill="$BG"/>
<rect class="cursor" x="20" y="15" width="8" height="16" fill="$PROMPT"/>
<rect x="0.5" y="0.5" width="$(awk "BEGIN{print $TW + 39}")" height="43" rx="8" fill="none" stroke="$BORDER"/>
</svg>
EOF
)

# ---------- write ----------
mkdir -p stats
card stats "${stats_body%$'\n'}" >stats/stats.svg
card langs "${langs_body%$'\n'}" >stats/langs.svg
echo "$typing" >stats/typing.svg
paste <(printf '%s\n' "${labels[@]}") <(printf '%s\n' "${values[@]}")
printf '%s\n' "${langs[@]#*$'\t'}"