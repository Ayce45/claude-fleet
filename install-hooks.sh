#!/usr/bin/env bash
# Wires the Claude Fleet hooks into ~/.claude/settings.json.
# - Makes a timestamped backup before any change.
# - Idempotent: re-running does not create duplicates.
# - Does NOT overwrite existing hooks (adds an entry alongside them).
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SRC/hooks/claude-fleet-hook.sh"
SETTINGS="$HOME/.claude/settings.json"

[ -f "$HOOK" ] || { echo "Hook not found: $HOOK" >&2; exit 1; }
chmod +x "$HOOK"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

BACKUP="$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
cp -f "$SETTINGS" "$BACKUP"
echo ">> Backup: $BACKUP"

# Map each Claude event -> Claude Fleet state
#   UserPromptSubmit -> working   (Claude starts working)
#   Notification     -> waiting   (Claude needs an action)
#   Stop             -> idle      (Claude finished responding)
#   SessionStart     -> idle      (session opened, at rest)
#   SessionEnd       -> end       (session closed -> file removed)
merge_event() {
  local event="$1" arg="$2" cmd
  cmd="$HOOK $arg"
  jq --arg event "$event" --arg cmd "$cmd" '
    .hooks //= {} |
    .hooks[$event] //= [] |
    # remove any Claude Fleet entry already present (idempotency)
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

echo ">> Hooks wired. Check:"
jq '.hooks | to_entries | map({event: .key, claude_fleet: ([.value[].hooks[]?.command] | map(select(startswith("'"$HOOK"'"))) )})' "$SETTINGS"

cat <<EOF

Done. The hooks are active for NEW Claude Code sessions.
(already-open sessions have not reloaded settings.json)

To revert: restore the backup
    cp -f "$BACKUP" "$SETTINGS"
EOF
