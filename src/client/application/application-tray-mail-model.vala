/* Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md. */
/* New downstream file: 2026-10-26. GPL-3.0-only; see COPYING. */
/* Licensed under GPL-3.0-only. See COPYING. */

/** Account-qualified, in-memory new-mail state. No account or network IO. */
internal class Application.TrayMailEntry : GLib.Object {
    internal int menu_id;
    internal GLib.Variant target;
    internal string label = _("New message");
    internal int64 received = GLib.get_real_time();
    internal uint64 sequence;

    internal TrayMailEntry(int menu_id, GLib.Variant target, uint64 sequence) {
        this.menu_id = menu_id;
        this.target = target;
        this.sequence = sequence;
    }
}

internal class Application.TrayMailModel : GLib.Object {
    private class FolderState : GLib.Object {
        internal uint64 generation;
        internal Gee.Set<string> ids = new Gee.HashSet<string>();
    }
    private Gee.Map<string,FolderState> folders = new Gee.HashMap<string,FolderState>();
    private Gee.Map<string,TrayMailEntry> entries = new Gee.HashMap<string,TrayMailEntry>();
    private uint64 generation = 0;
    private uint64 sequence = 0;
    private int next_menu_id = 100;
    internal signal void changed();
    internal int total { get { return this.entries.size; } }

    internal uint64 set_folder(string folder, GLib.Variant[] targets) {
        var state = new FolderState();
        state.generation = ++this.generation;
        foreach (var target in targets) {
            string key = target.print(false);
            state.ids.add(key);
            if (!this.entries.has_key(key)) {
                this.entries.set(key, new TrayMailEntry(
                    this.next_menu_id++, target, ++this.sequence
                ));
            }
        }
        this.folders.set(folder, state);
        var active = new Gee.HashSet<string>();
        foreach (var current in this.folders.values) active.add_all(current.ids);
        foreach (string key in this.entries.keys.to_array()) {
            if (!active.contains(key)) this.entries.unset(key);
        }
        if (targets.length == 0) this.folders.unset(folder);
        changed();
        return state.generation;
    }

    internal bool set_details(string folder, uint64 expected_generation,
                              GLib.Variant target, string sender,
                              string subject, int64 received) {
        string key = target.print(false);
        var state = this.folders.get(folder);
        var entry = this.entries.get(key);
        if (state == null || state.generation != expected_generation ||
            !state.ids.contains(key) || entry == null) return false;
        string clean_sender = Convey.String.reduce_whitespace(sender);
        string clean_subject = Convey.String.reduce_whitespace(subject);
        string label = clean_sender != ""
            ? "%s — %s".printf(clean_sender, clean_subject) : clean_subject;
        if (entry.label != label || (received > 0 && entry.received != received)) {
            entry.label = label;
            if (received > 0) entry.received = received;
            changed();
        }
        return true;
    }

    internal Gee.List<TrayMailEntry> latest(int limit = 5) {
        var sorted = new Gee.ArrayList<TrayMailEntry>();
        sorted.add_all(this.entries.values);
        sorted.sort((a, b) => {
            if (a.received != b.received) return a.received > b.received ? -1 : 1;
            return a.sequence == b.sequence ? 0 : (a.sequence > b.sequence ? -1 : 1);
        });
        var result = new Gee.ArrayList<TrayMailEntry>();
        foreach (var entry in sorted) {
            if (result.size >= limit) break;
            result.add(entry);
        }
        return result;
    }
}
