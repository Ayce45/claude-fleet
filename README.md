# Claude Fleet — GNOME indicator for Claude Code sessions

Shows the number of Claude Code sessions and their state in the GNOME top bar,
with small status badges:

```
🤖 🟢2 🟠1 ⚪0
```

- 🟢 **working** — Claude is processing a request (in progress)
- 🟠 **waiting** — Claude needs an action (permission, question…)
- ⚪ **idle** — Claude finished responding / session at rest

Click the icon → per-session detail (state + working directory).

## How it works

No fragile process inspection: Claude Code exposes **hooks**. A small script
(`hooks/claude-fleet-hook.sh`) is wired to the events and writes each session's
state to `$XDG_RUNTIME_DIR/claude-fleet/<session_id>.json`:

| Claude event       | State written |
|--------------------|---------------|
| `UserPromptSubmit` | working       |
| `Notification`     | waiting       |
| `Stop`             | idle          |
| `SessionStart`     | idle          |
| `SessionEnd`       | (removed)     |

The extension reads this directory every 2 s and counts the states. If a session
crashed without `SessionEnd`, the extension detects that the `claude` PID is dead
and removes the orphan file (self-healing).

## Installation

```bash
./install.sh         # copies the extension into ~/.local/share/gnome-shell/extensions
./install-hooks.sh   # wires the hooks into ~/.claude/settings.json (with backup)
```

⚠️ **Wayland**: GNOME Shell does not reload on the fly.
→ **Log out / log back in** to load the extension.

Hooks only apply to **new** Claude sessions (settings.json is read when `claude`
starts).

## Uninstall

```bash
gnome-extensions disable claude-fleet@Ayce45
rm -rf ~/.local/share/gnome-shell/extensions/claude-fleet@Ayce45
# restore the settings.json backup printed by install-hooks.sh:
cp -f ~/.claude/settings.json.bak.<timestamp> ~/.claude/settings.json
```

## Prototype limitations

- Hook-based states: a `working` state stays shown until `Stop` fires (so it's
  faithful, but depends on Claude's hooks).
- No preferences page (polling interval, emoji/badge choice) — hardcoded.
- Tested on GNOME Shell 43 (Wayland). `shell-version` metadata: 43, 44.
  For GNOME ≥ 45 you would need to port `extension.js` to ESM modules.

## License

[MIT](LICENSE) © Ayce45
