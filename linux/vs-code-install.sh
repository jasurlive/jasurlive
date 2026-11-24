#!/usr/bin/env bash
# Install a PINNED 1.91.1 version of official Visual Studio Code (Microsoft build),
# with auto-updates disabled, plus your settings, keybindings and extensions.
# No AUR, no package manager: downloads the exact tarball from Microsoft.
#
# Run standalone:  ./vscode/install-vscode.sh
# (install.sh calls this automatically.)
set -euo pipefail

# ---- the exact version you use -------------------------------------------
VSCODE_VERSION="1.91.1"
VSCODE_COMMIT="f1e16e1e6214d7c44d078b1f0607b2388f29d729"
# Microsoft permalink: redirects to the tarball for this exact version.
URL="https://update.code.visualstudio.com/${VSCODE_VERSION}/linux-x64/stable"
# --------------------------------------------------------------------------

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info() { printf '\e[1;34m==>\e[0m %s\n' "$*"; }

# 1) Install the pinned build to /opt/vscode (skip if already correct version)
installed="$(grep -oE '"version":[[:space:]]*"[^"]+"' /opt/vscode/resources/app/package.json 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)"
if [[ $installed == "$VSCODE_VERSION" ]]; then
  info "VSCode $VSCODE_VERSION already installed at /opt/vscode"
else
  info "Downloading VSCode $VSCODE_VERSION (Microsoft stable, x64)"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  curl -fL "$URL" -o "$tmp/vscode.tar.gz"

  # Verify we got the expected commit before touching /opt
  if ! tar -xzf "$tmp/vscode.tar.gz" -C "$tmp"; then
    echo "Download/extract failed"; exit 1
  fi
  src="$(find "$tmp" -maxdepth 1 -type d -name 'VSCode-linux-x64' | head -1)"
  got_commit="$(grep -oE '"commit":\s*"[^"]+"' "$src/resources/app/product.json" | head -1 | grep -oE '[0-9a-f]{40}' || true)"
  if [[ -n $got_commit && $got_commit != "$VSCODE_COMMIT" ]]; then
    echo "WARNING: downloaded commit $got_commit != expected $VSCODE_COMMIT"
  fi

  info "Installing to /opt/vscode (needs sudo)"
  sudo rm -rf /opt/vscode
  sudo mv "$src" /opt/vscode
  sudo ln -sf /opt/vscode/bin/code /usr/local/bin/code
fi

CODE=/opt/vscode/bin/code

# 2) Link user settings + keybindings (symlink -> repo, backing up originals)
info "Linking VSCode settings and keybindings"
mkdir -p "$HOME/.config/Code/User"
for f in settings.json keybindings.json; do
  dst="$HOME/.config/Code/User/$f"
  [[ -e $dst && ! -L $dst ]] && mv "$dst" "$dst.pre-dotfiles.$(date +%s)"
  ln -sf "$HERE/$f" "$dst"
done

# 3) Install extensions (pinned-version editor won't auto-update them)
if [[ -s $HERE/extensions.txt ]]; then
  info "Installing extensions"
  while read -r ext; do
    [[ -z $ext || $ext == \#* ]] && continue
    "$CODE" --install-extension "$ext" --force || echo "  (failed: $ext)"
  done < "$HERE/extensions.txt"
fi

info "VSCode $VSCODE_VERSION ready. Auto-update is off (update.mode=none in settings.json)."