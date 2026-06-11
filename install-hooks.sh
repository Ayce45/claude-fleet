#!/usr/bin/env bash
# Câble les hooks Claude Fleet dans ~/.claude/settings.json.
# - Fait une sauvegarde horodatée avant toute modif.
# - Idempotent : relancer ne crée pas de doublons.
# - N'écrase PAS les hooks existants (ajoute une entrée à côté).
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SRC/hooks/claude-fleet-hook.sh"
SETTINGS="$HOME/.claude/settings.json"

[ -f "$HOOK" ] || { echo "Hook introuvable: $HOOK" >&2; exit 1; }
chmod +x "$HOOK"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

BACKUP="$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
cp -f "$SETTINGS" "$BACKUP"
echo ">> Sauvegarde : $BACKUP"

# Pour chaque évènement Claude -> état Claude Fleet
#   UserPromptSubmit -> working   (Claude se met à bosser)
#   Notification     -> waiting   (Claude réclame une action)
#   Stop             -> idle      (Claude a fini de répondre)
#   SessionStart     -> idle      (session ouverte, au repos)
#   SessionEnd       -> end       (session fermée -> fichier supprimé)
merge_event() {
  local event="$1" arg="$2" cmd
  cmd="$HOOK $arg"
  jq --arg event "$event" --arg cmd "$cmd" '
    .hooks //= {} |
    .hooks[$event] //= [] |
    # retire une éventuelle entrée Claude Fleet déjà présente (idempotence)
    .hooks[$event] |= map(
      select(([.hooks[]?.command] | map(startswith("'"$HOOK"'")) | any) | not)
    ) |
    .hooks[$event] += [ { "hooks": [ { "type": "command", "command": $cmd } ] } ]
  ' "$SETTINGS" > "$SETTINGS.tmp" && mv -f "$SETTINGS.tmp" "$SETTINGS"
}

merge_event UserPromptSubmit working
merge_event Notification     waiting
merge_event Stop             idle
merge_event SessionStart     idle
merge_event SessionEnd       end

echo ">> Hooks câblés. Vérif :"
jq '.hooks | to_entries | map({event: .key, claude_fleet: ([.value[].hooks[]?.command] | map(select(startswith("'"$HOOK"'"))) )})' "$SETTINGS"

cat <<EOF

OK. Les hooks sont actifs pour les NOUVELLES sessions Claude Code.
(les sessions déjà ouvertes n'ont pas rechargé settings.json)

Pour annuler : restaure la sauvegarde
    cp -f "$BACKUP" "$SETTINGS"
EOF
