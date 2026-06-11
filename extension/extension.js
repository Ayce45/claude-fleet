/* Claude Fleet — extension GNOME Shell 43/44 (API legacy GJS, pas ESM)
 *
 * Lit les fichiers d'état écrits par claude-fleet-hook.sh dans
 *   $XDG_RUNTIME_DIR/claude-fleet/<session_id>.json
 * et affiche un compteur par état dans le panel.
 */
'use strict';

const { St, Clutter, GObject, Gio, GLib } = imports.gi;
const Main = imports.ui.main;
const PanelMenu = imports.ui.panelMenu;
const PopupMenu = imports.ui.popupMenu;

const STATE_DIR = GLib.build_filenamev([
    GLib.getenv('XDG_RUNTIME_DIR') || '/tmp',
    'claude-fleet',
]);
const POLL_SECONDS = 2;

const ICONS = {
    working: '🟢',  // Claude traite une requête
    waiting: '🟠',  // Claude attend une action de l'utilisateur
    idle: '⚪',     // Claude a fini / inactif
};
const ORDER = { working: 0, waiting: 1, idle: 2 };

function pidAlive(pid) {
    if (!pid || pid <= 0)
        return true; // pid inconnu -> on ne supprime pas par précaution
    return GLib.file_test('/proc/' + pid, GLib.FileTest.EXISTS);
}

const ClaudeFleetIndicator = GObject.registerClass(
class ClaudeFleetIndicator extends PanelMenu.Button {
    _init() {
        super._init(0.0, 'Claude Fleet');

        this._box = new St.BoxLayout({ style_class: 'claude-fleet-box' });
        this._robot = new St.Label({
            text: '🤖',
            y_align: Clutter.ActorAlign.CENTER,
            style_class: 'claude-fleet-robot',
        });
        this._counts = new St.Label({
            text: '',
            y_align: Clutter.ActorAlign.CENTER,
            style_class: 'claude-fleet-counts',
        });
        this._box.add_child(this._robot);
        this._box.add_child(this._counts);
        this.add_child(this._box);

        this._section = new PopupMenu.PopupMenuSection();
        this.menu.addMenuItem(this._section);

        this._refresh();
        this._timeout = GLib.timeout_add_seconds(
            GLib.PRIORITY_DEFAULT, POLL_SECONDS, () => {
                this._refresh();
                return GLib.SOURCE_CONTINUE;
            });
    }

    _readSessions() {
        const sessions = [];
        const dir = Gio.File.new_for_path(STATE_DIR);
        let en;
        try {
            en = dir.enumerate_children(
                'standard::name', Gio.FileQueryInfoFlags.NONE, null);
        } catch (e) {
            return sessions; // le dossier n'existe pas encore -> 0 session
        }

        let info;
        while ((info = en.next_file(null)) !== null) {
            const name = info.get_name();
            if (!name.endsWith('.json'))
                continue;
            const path = GLib.build_filenamev([STATE_DIR, name]);

            let contents;
            try {
                const [ok, bytes] = GLib.file_get_contents(path);
                if (!ok)
                    continue;
                contents = new TextDecoder().decode(bytes);
            } catch (e) {
                continue;
            }

            let data;
            try {
                data = JSON.parse(contents);
            } catch (e) {
                continue;
            }

            // Auto-réparation : fichier orphelin (process claude mort) -> on le supprime
            if (!pidAlive(data.pid)) {
                try { GLib.unlink(path); } catch (e) {}
                continue;
            }
            sessions.push(data);
        }
        en.close(null);
        return sessions;
    }

    _refresh() {
        const sessions = this._readSessions();
        const counts = { working: 0, waiting: 0, idle: 0 };
        for (const s of sessions) {
            const st = counts[s.state] !== undefined ? s.state : 'idle';
            counts[st]++;
        }
        const total = sessions.length;

        // Panel : 🟢2 🟠1 ⚪0  (les "petits logos" demandés)
        this._counts.text =
            `${ICONS.working}${counts.working}` +
            ` ${ICONS.waiting}${counts.waiting}` +
            ` ${ICONS.idle}${counts.idle}`;

        // Menu déroulant : résumé + détail par session
        this._section.removeAll();

        const summary = new PopupMenu.PopupMenuItem(
            `${total} session(s) Claude`, { reactive: false });
        this._section.addMenuItem(summary);
        this._section.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        if (total === 0) {
            this._section.addMenuItem(new PopupMenu.PopupMenuItem(
                'Aucune session active', { reactive: false }));
            return;
        }

        sessions.sort((a, b) =>
            (ORDER[a.state] ?? 3) - (ORDER[b.state] ?? 3));

        const home = GLib.get_home_dir();
        for (const s of sessions) {
            const icon = ICONS[s.state] || ICONS.idle;
            let cwd = s.cwd || '?';
            if (home && cwd.startsWith(home))
                cwd = '~' + cwd.slice(home.length);
            const item = new PopupMenu.PopupMenuItem(
                `${icon}  ${cwd}`, { reactive: false });
            this._section.addMenuItem(item);
        }
    }

    destroy() {
        if (this._timeout) {
            GLib.source_remove(this._timeout);
            this._timeout = null;
        }
        super.destroy();
    }
});

let _indicator = null;

function init() {}

function enable() {
    _indicator = new ClaudeFleetIndicator();
    Main.panel.addToStatusArea('claude-fleet', _indicator);
}

function disable() {
    if (_indicator) {
        _indicator.destroy();
        _indicator = null;
    }
}
