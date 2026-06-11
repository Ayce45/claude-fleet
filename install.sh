#!/usr/bin/env bash
# Installe l'extension GNOME "Claude Fleet" (partie panel uniquement, sans toucher
# à ~/.claude/settings.json). Pour câbler les hooks, lance ensuite install-hooks.sh.
set -euo pipefail

UUID="claude-fleet@ejuge"
SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.local/share/gnome-shell/extensions/$UUID"

echo ">> Installation de l'extension dans $DEST"
mkdir -p "$DEST"
cp -f "$SRC/extension/metadata.json" "$DEST/"
cp -f "$SRC/extension/extension.js"  "$DEST/"
cp -f "$SRC/extension/stylesheet.css" "$DEST/"

echo ">> Rend le hook exécutable"
chmod +x "$SRC/hooks/claude-fleet-hook.sh"

echo ">> Activation de l'extension"
gnome-extensions enable "$UUID" 2>/dev/null || \
  echo "   (activation échouée : active-la après relog via 'gnome-extensions enable $UUID')"

cat <<EOF

OK. Extension copiée.

⚠️  Wayland : on ne peut pas recharger GNOME Shell à chaud.
    -> Déconnecte/reconnecte ta session (logout/login) pour la charger.

Ensuite, câble les hooks Claude Code :
    $SRC/install-hooks.sh
EOF
