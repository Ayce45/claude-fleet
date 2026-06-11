#!/usr/bin/env bash
# Installs the "Claude Fleet" GNOME extension (panel part only, without touching
# ~/.claude/settings.json). To wire the hooks, run install-hooks.sh afterwards.
set -euo pipefail

UUID="claude-fleet@Ayce45"
SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.local/share/gnome-shell/extensions/$UUID"

echo ">> Installing the extension into $DEST"
mkdir -p "$DEST"
cp -f "$SRC/extension/metadata.json" "$DEST/"
cp -f "$SRC/extension/extension.js"  "$DEST/"
cp -f "$SRC/extension/stylesheet.css" "$DEST/"

echo ">> Making the hook executable"
chmod +x "$SRC/hooks/claude-fleet-hook.sh"

echo ">> Enabling the extension"
gnome-extensions enable "$UUID" 2>/dev/null || \
  echo "   (enable failed: enable it after relog via 'gnome-extensions enable $UUID')"

cat <<EOF

Done. Extension copied.

⚠️  Wayland: GNOME Shell cannot be reloaded on the fly.
    -> Log out / log back in to load it.

Next, wire the Claude Code hooks:
    $SRC/install-hooks.sh
EOF
