/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright © 2022 John Renner <john@jrenner.net>
 * Copyright © 2022 Cédric Bellegarde <cedric.bellegarde@adishatz.org>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

// The whole goal of this class to wrap the ConversationMonitor with a view that presents a sorted list
public class ConversationList.Model : Object, ListModel {
    private class Entry {
        public GriabuntuMail.App.Conversation conversation;
        public bool leaving = false;

        public Entry(GriabuntuMail.App.Conversation conversation) {
            this.conversation = conversation;
        }
    }

    private GLib.GenericArray<Entry> entries = new GLib.GenericArray<Entry>();

    // More than one monitor when several inboxes are shown combined;
    // conversations from all of them are merged into a single date
    // ordered list.
    internal Gee.Collection<GriabuntuMail.App.ConversationMonitor> monitors {
        get; private set;
    }

    private int scanning = 0;

    private const uint READY_TIMEOUT_MS = 2000;

    /** Whether every monitor has finished its first scan. */
    public bool is_ready { get; private set; default = false; }

    /**
     * Whether only unread conversations are listed.
     *
     * Conversations that are read while listed stay until this changes.
     */
    public bool unread_only {
        get { return this._unread_only; }
        set {
            if (this._unread_only != value) {
                this._unread_only = value;
                apply_filter();
            }
        }
    }
    private bool _unread_only = false;

    private Gee.Set<GriabuntuMail.App.ConversationMonitor> unscanned =
        new Gee.HashSet<GriabuntuMail.App.ConversationMonitor>();

    internal Model(Gee.Collection<GriabuntuMail.App.ConversationMonitor> monitors) {
        this.monitors = monitors;
        this.unscanned.add_all(monitors);
        GLib.Timeout.add(READY_TIMEOUT_MS, () => {
            set_ready();
            return GLib.Source.REMOVE;
        });

        foreach (var monitor in monitors) {
            monitor.conversations_added.connect(on_conversations_added);
            monitor.conversation_appended.connect(on_conversation_updated);
            monitor.conversation_trimmed.connect(on_conversation_updated);
            monitor.conversations_removed.connect(on_conversations_removed);
            monitor.scan_started.connect(on_scan_started);
            monitor.scan_completed.connect(on_scan_completed);
        }
    }

    ~Model() {
        foreach (var monitor in this.monitors) {
            monitor.conversations_added.disconnect(on_conversations_added);
            monitor.conversation_appended.disconnect(on_conversation_updated);
            monitor.conversation_trimmed.disconnect(on_conversation_updated);
            monitor.conversations_removed.disconnect(on_conversations_removed);
            monitor.scan_started.disconnect(on_scan_started);
            monitor.scan_completed.disconnect(on_scan_completed);
        }
    }

    /** The folders being displayed. */
    internal Gee.Collection<GriabuntuMail.Folder> get_folders() {
        var folders = new Gee.ArrayList<GriabuntuMail.Folder>();
        foreach (var monitor in this.monitors) {
            folders.add(monitor.base_folder);
        }
        return folders;
    }

    public signal void conversations_added(bool start);
    public signal void conversations_removed(bool start);
    public signal void conversations_loaded();
    public signal void conversation_updated(GriabuntuMail.App.Conversation convo);
    public signal void conversation_leaving(uint position);
    public signal void ready();

    private static int compare(GriabuntuMail.App.Conversation a, GriabuntuMail.App.Conversation b) {
        return Util.Email.compare_conversation_descending(a, b);
    }

    // ------------------------
    //  Scanning and load_more
    // ------------------------

    private void on_scan_started(GriabuntuMail.App.ConversationMonitor source) {
        this.scanning++;
    }

    private void set_ready() {
        if (!this.is_ready) {
            this.is_ready = true;
            ready();
        }
    }

    private void on_scan_completed(GriabuntuMail.App.ConversationMonitor source) {
        this.unscanned.remove(source);
        if (this.unscanned.is_empty) {
            set_ready();
        }
        this.scanning = int.max(0, this.scanning - 1);
        GLib.Timeout.add(100, () => {
            if (this.scanning == 0) {
                conversations_loaded();
            }
            return false;
        });
    }

    public bool load_more(int amount) {
        if (this.scanning > 0) {
            return false;
        }

        foreach (var monitor in this.monitors) {
            monitor.min_window_count += amount;
        }
        return true;
    }


    // ------------------------
    // Model
    // ------------------------

    public Object? get_item(uint position) {
        if (position >= this.entries.length) {
            return null;
        }
        return this.entries[position].conversation;
    }

    public Type get_item_type() {
        return typeof(GriabuntuMail.App.Conversation);
    }

    public uint get_n_items() {
        return this.entries.length;
    }

    private bool is_valid(GriabuntuMail.App.Conversation convo) {
        // The conversation may be bogus, if so don't do anything
        if (convo.get_latest_recv_email(ANYWHERE) == null) {
            debug("Cannot add conversation: last email is null");
            return false;
        }
        return true;
    }

    private bool is_shown(GriabuntuMail.App.Conversation convo) {
        return !this._unread_only || convo.is_unread();
    }

    private void apply_filter() {
        if (this._unread_only) {
            var leaving = new Gee.ArrayList<Entry>();
            foreach (var entry in this.entries) {
                if (!entry.leaving && !is_shown(entry.conversation)) {
                    leaving.add(entry);
                }
            }
            if (!leaving.is_empty) {
                remove_later(leaving, true);
            }
        } else {
            var listed = new Gee.HashSet<GriabuntuMail.App.Conversation>();
            foreach (var entry in this.entries) {
                if (!entry.leaving) {
                    listed.add(entry.conversation);
                }
            }
            var missing = new Gee.ArrayList<GriabuntuMail.App.Conversation>();
            foreach (var monitor in this.monitors) {
                foreach (var convo in monitor.read_only_view) {
                    if (!listed.contains(convo)) {
                        missing.add(convo);
                    }
                }
            }
            if (!missing.is_empty) {
                on_conversations_added(missing);
            }
        }
    }

    private int find_live(GriabuntuMail.App.Conversation convo) {
        for (int i = 0; i < this.entries.length; i++) {
            if (!this.entries[i].leaving && this.entries[i].conversation == convo) {
                return i;
            }
        }
        return -1;
    }

    // Marks entries as leaving, then removes them once their rows have
    // animated out
    private void remove_later(Gee.Collection<Entry> leaving, bool notify) {
        foreach (var entry in leaving) {
            entry.leaving = true;
            uint position;
            if (this.entries.find(entry, out position)) {
                conversation_leaving(position);
            }
        }
        GLib.Timeout.add(Row.ANIMATION_DURATION_MS + 50, () => {
            if (notify) {
                conversations_removed(true);
            }
            foreach (var entry in leaving) {
                uint position;
                if (this.entries.find(entry, out position)) {
                    this.entries.remove_index(position);
                    this.items_changed(position, 1, 0);
                }
            }
            if (notify) {
                conversations_removed(false);
            }
            return GLib.Source.REMOVE;
        });
    }

    private void on_conversations_added(Gee.Collection<GriabuntuMail.App.Conversation> conversations) {
        debug("Adding %d conversations.", conversations.size);

        conversations_added(true);

        var added = new Gee.ArrayList<GriabuntuMail.App.Conversation>();
        foreach (GriabuntuMail.App.Conversation convo in conversations) {
            if (is_shown(convo) && is_valid(convo)) {
                added.add(convo);
            }
        }
        added.sort(compare);

        uint i = 0;
        int j = 0;
        while (j < added.size) {
            while (i < this.entries.length &&
                   (this.entries[i].leaving ||
                    compare(this.entries[i].conversation, added[j]) <= 0)) {
                i++;
            }
            uint start = i;
            do {
                this.entries.insert((int) i, new Entry(added[j]));
                i++;
                j++;
            } while (j < added.size &&
                     (i == this.entries.length ||
                      (!this.entries[i].leaving &&
                       compare(added[j], this.entries[i].conversation) < 0)));
            this.items_changed(start, 0, i - start);
        }

        conversations_added(false);

        debug("Added %d/%d conversations.", added.size, conversations.size);
    }

    private void on_conversations_removed(Gee.Collection<GriabuntuMail.App.Conversation> conversations) {
        debug("Removing %d conversations.", conversations.size);

        var leaving = new Gee.ArrayList<Entry>();
        foreach (GriabuntuMail.App.Conversation convo in conversations) {
            int position = find_live(convo);
            if (position >= 0) {
                leaving.add(this.entries[position]);
            }
        }
        if (!leaving.is_empty) {
            remove_later(leaving, true);
        }
    }

    private void on_conversation_updated(GriabuntuMail.App.ConversationMonitor sender, GriabuntuMail.App.Conversation convo, Gee.Collection<GriabuntuMail.Email> emails) {
        conversation_updated(convo);

        int position = find_live(convo);
        if (position < 0) {
            if (this._unread_only && convo.is_unread() &&
                sender.read_only_view.contains(convo)) {
                on_conversations_added(GriabuntuMail.Collection.single(convo));
            }
            return;
        }

        bool in_place = true;
        for (int i = position - 1; i >= 0; i--) {
            if (!this.entries[i].leaving) {
                in_place = compare(this.entries[i].conversation, convo) <= 0;
                break;
            }
        }
        for (int i = position + 1; in_place && i < this.entries.length; i++) {
            if (!this.entries[i].leaving) {
                in_place = compare(convo, this.entries[i].conversation) <= 0;
                break;
            }
        }
        if (in_place) {
            return;
        }

        // Inserts the conversation at its new position and animates the
        // old row out at the same time
        Entry ghost = this.entries[position];
        uint insert_at = this.entries.length;
        for (uint i = 0; i < this.entries.length; i++) {
            Entry entry = this.entries[i];
            if (entry != ghost && !entry.leaving &&
                compare(convo, entry.conversation) < 0) {
                insert_at = i;
                break;
            }
        }
        this.entries.insert((int) insert_at, new Entry(convo));
        this.items_changed(insert_at, 0, 1);

        var leaving = new Gee.ArrayList<Entry>();
        leaving.add(ghost);
        remove_later(leaving, false);
    }
}
