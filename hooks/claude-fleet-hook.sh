#!/usr/bin/env bash
# claude-fleet-hook.sh — écrit l'état d'une session Claude Code dans un fichier
# que l'extension GNOME "Claude Fleet" lit en boucle.
#
# Usage (appelé par les hooks Claude Code, JSON sur stdin) :
#   claude-fleet-hook.sh working   # Claude traite une requête (UserPromptSubmit)
#   claude-fleet-hook.sh waiting   # Claude attend une action user (Notification)
#   claude-fleet-hook.sh idle      # Claude a fini de répondre (Stop / SessionStart)
#   claude-fleet-hook.sh end       # Session terminée (SessionEnd) -> supprime le fichier
#
# IMPORTANT : ce script n'écrit JAMAIS sur stdout (sinon Claude l'ajoute au contexte
# pour les hooks UserPromptSubmit/SessionStart). Tout va dans le fichier d'état.

set -euo pipefail

state="${1:-idle}"
dir="${XDG_RUNTIME_DIR:-/tmp}/claude-fleet"
mkdir -p "$dir"

# Lit le JSON du hook (une seule fois)
input="$(cat 2>/dev/null || true)"

sid="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null || true)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)"
[ -z "$sid" ] && exit 0

f="$dir/$sid.json"

if [ "$state" = "end" ]; then
  rm -f "$f"
  exit 0
fi

# Remonte la chaîne des parents pour trouver le vrai PID du process `claude`
# (utilisé par l'extension pour détecter les sessions mortes / fichiers orphelins).
find_claude_pid() {
  local p="$PPID" i=0
  while [ "$p" -gt 1 ] && [ "$i" -lt 8 ]; do
    if [ "$(cat "/proc/$p/comm" 2>/dev/null || true)" = "claude" ]; then
      echo "$p"; return
    fi
    p="$(awk '{print $4}' "/proc/$p/stat" 2>/dev/null || echo "")"
    [ -z "$p" ] && break
    i=$((i + 1))
  done
  echo "$PPID"
}
pid="$(find_claude_pid)"

# Écriture atomique (tmp + mv) pour que l'extension ne lise jamais un fichier partiel.
tmp="$dir/.$sid.$$.tmp"
jq -nc \
  --arg sid "$sid" \
  --arg state "$state" \
  --arg cwd "$cwd" \
  --argjson pid "${pid:-0}" \
  --argjson ts "$(date +%s)" \
  '{session_id:$sid, state:$state, cwd:$cwd, pid:$pid, ts:$ts}' > "$tmp" 2>/dev/null \
  && mv -f "$tmp" "$f"

exit 0
