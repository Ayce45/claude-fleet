# Claude Fleet — indicateur GNOME des sessions Claude Code

Affiche dans la barre du haut GNOME le nombre de sessions Claude Code et leur état,
avec des petits logos :

```
🤖 🟢2 🟠1 ⚪0
```

- 🟢 **working** — Claude traite une requête (en cours)
- 🟠 **waiting** — Claude réclame une action (permission, question…)
- ⚪ **idle** — Claude a fini de répondre / session au repos

Clic sur l'icône → détail par session (état + dossier de travail).

## Comment ça marche

Pas d'inspection de processus fragile : Claude Code expose des **hooks**. Un petit
script (`hooks/claude-fleet-hook.sh`) est branché sur les évènements et écrit l'état
de chaque session dans `$XDG_RUNTIME_DIR/claude-fleet/<session_id>.json` :

| Évènement Claude   | État écrit |
|--------------------|------------|
| `UserPromptSubmit` | working    |
| `Notification`     | waiting    |
| `Stop`             | idle       |
| `SessionStart`     | idle       |
| `SessionEnd`       | (supprimé) |

L'extension lit ce dossier toutes les 2 s et compte les états. Si une session a
planté sans `SessionEnd`, l'extension détecte que le PID `claude` est mort et
supprime le fichier orphelin (auto-réparation).

## Installation

```bash
./install.sh         # copie l'extension dans ~/.local/share/gnome-shell/extensions
./install-hooks.sh   # câble les hooks dans ~/.claude/settings.json (avec backup)
```

⚠️ **Wayland** (ton cas) : GNOME Shell ne se recharge pas à chaud.
→ **Déconnexion / reconnexion** de la session pour charger l'extension.

Les hooks ne s'appliquent qu'aux **nouvelles** sessions Claude (settings.json est lu
au démarrage de `claude`).

## Désinstallation

```bash
gnome-extensions disable claude-fleet@ejuge
rm -rf ~/.local/share/gnome-shell/extensions/claude-fleet@ejuge
# restaurer la sauvegarde settings.json affichée par install-hooks.sh :
cp -f ~/.claude/settings.json.bak.<horodatage> ~/.claude/settings.json
```

## Limites du prototype

- États basés sur les hooks : un `working` reste affiché tant que `Stop` n'a pas
  tiré (donc fidèle, mais dépend des hooks Claude).
- Pas de page de préférences (intervalle de polling, choix emoji/pastilles) — codé en dur.
- Testé sur GNOME Shell 43 (Wayland). Métadonnée `shell-version` : 43, 44.
  Pour GNOME ≥ 45 il faudrait porter `extension.js` en modules ESM.
