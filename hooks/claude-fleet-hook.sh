#!/usr/bin/env bash
# claude-fleet-hook.sh — writes the state of a Claude Code session to a file
# that the "Claude Fleet" GNOME extension polls.
#
# Usage (called by Claude Code hooks, JSON on stdin):
#   claude-fleet-hook.sh working   # Claude is processing a request (UserPromptSubmit)
#   claude-fleet-hook.sh waiting   # Claude waits for a user action (Notification)
#   claude-fleet-hook.sh idle      # Claude finished responding (Stop / SessionStart)
#   claude-fleet-hook.sh end       # Session ended (SessionEnd) -> removes the file
#
# IMPORTANT: this script NEVER writes to stdout (otherwise Claude would add it to
# the context for the UserPromptSubmit/SessionStart hooks). Everything goes to the
# state file.

set -euo pipefail

state="${1:-idle}"
dir="${XDG_RUNTIME_DIR:-/tmp}/claude-fleet"
mkdir -p "$dir"

# Read the hook JSON (only once)
input="$(cat 2>/dev/null || true)"

sid="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null || true)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)"
[ -z "$sid" ] && exit 0

f="$dir/$sid.json"

if [ "$state" = "end" ]; then
  rm -f "$f"
  exit 0
fi

# Walk up the parent chain to find the real `claude` process PID
# (used by the extension to detect dead sessions / orphan files).
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

# Atomic write (tmp + mv) so the extension never reads a partial file.
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
