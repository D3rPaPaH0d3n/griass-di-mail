/* Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md. */
/* New downstream file: 2026-10-26. GPL-3.0-only; see COPYING. */
/* Licensed under GPL-3.0-only. See COPYING. */

/** Native SNI/DBusMenu integration; no GTK3 dependency or helper process. */
internal class Application.StatusIcon : GLib.Object {
    internal TrayItem item = new TrayItem();
    internal TrayMenu menu = new TrayMenu();
    internal TrayMailModel new_mail = new TrayMailModel();
    private GLib.DBusConnection connection;
    private string bus_name;
    private uint item_id = 0;
    private uint menu_id = 0;
    private uint watch_id = 0;
    private ulong menu_selected_id = 0;
    private ulong mail_selected_id = 0;
    private ulong model_changed_id = 0;
    private Gee.Map<string,GLib.Cancellable> requests = new Gee.HashMap<string,GLib.Cancellable>();
    private GLib.Cancellable cancellable = new GLib.Cancellable();

    internal StatusIcon(GLib.DBusConnection connection, string bus_name)
        throws GLib.Error {
        this.connection = connection;
        this.bus_name = bus_name;
        try {
            this.item_id = connection.register_object("/StatusNotifierItem", this.item);
            this.menu_id = connection.register_object("/StatusNotifierItem/Menu", this.menu);
            this.menu_selected_id = this.menu.selected.connect((id) => {
                switch (id) {
                case 1: this.item.request_open(); break;
                case 2: this.item.request_compose(); break;
                case 4: this.item.quit_requested(); break;
                }
            });
            this.mail_selected_id = this.menu.mail_selected.connect(
                (target) => this.item.email_requested(target)
            );
            this.model_changed_id = this.new_mail.changed.connect(refresh_new_mail);
            this.watch_id = GLib.Bus.watch_name_on_connection(
                connection, "org.kde.StatusNotifierWatcher", NONE,
                on_watcher_appeared, null
            );
        } catch (GLib.Error error) {
            close();
            throw error;
        }
    }

    internal void close() {
        this.cancellable.cancel();
        foreach (var request in this.requests.values) request.cancel();
        this.requests.clear();
        if (this.menu_selected_id != 0) {
            GLib.SignalHandler.disconnect(this.menu, this.menu_selected_id);
            this.menu_selected_id = 0;
        }
        if (this.mail_selected_id != 0) {
            GLib.SignalHandler.disconnect(this.menu, this.mail_selected_id);
            this.mail_selected_id = 0;
        }
        if (this.model_changed_id != 0) {
            GLib.SignalHandler.disconnect(this.new_mail, this.model_changed_id);
            this.model_changed_id = 0;
        }
        if (this.watch_id != 0) {
            GLib.Bus.unwatch_name(this.watch_id);
            this.watch_id = 0;
        }
        if (this.menu_id != 0) {
            this.connection.unregister_object(this.menu_id);
            this.menu_id = 0;
        }
        if (this.item_id != 0) {
            this.connection.unregister_object(this.item_id);
            this.item_id = 0;
        }
    }

    private void refresh_new_mail() {
        this.item.set_new_mail_count(this.new_mail.total);
        this.menu.set_new_mail(this.new_mail.total, this.new_mail.latest());
    }

    internal async void update_new_mail(string key, Convey.Folder folder,
        Gee.Map<Convey.EmailIdentifier,GLib.Variant> targets) {
        var old = this.requests.get(key);
        if (old != null) old.cancel();
        this.requests.unset(key);
        if (this.cancellable.is_cancelled()) return;
        uint64 generation = this.new_mail.set_folder(key, targets.values.to_array());
        if (targets.is_empty) return;
        var ids = new Gee.ArrayList<Convey.EmailIdentifier>();
        ids.add_all(targets.keys);
        ids.sort((a, b) => b.natural_sort_comparator(a));
        while (ids.size > 5) ids.remove_at(ids.size - 1);
        var request = new GLib.Cancellable();
        this.requests.set(key, request);
        try {
            // Metadata only, at most five locally cached messages/folder.
            var emails = yield folder.list_email_by_sparse_id_async(
                ids, Convey.Email.Field.ORIGINATORS | Convey.Email.Field.SUBJECT |
                Convey.Email.Field.PROPERTIES, LOCAL_ONLY, request
            );
            if (!request.is_cancelled() && emails != null) {
                foreach (var email in emails) {
                    var target = targets.get(email.id);
                    if (target == null) continue;
                    var sender = Util.Email.get_summary_contact_mailbox(email, false);
                    this.new_mail.set_details(key, generation, target,
                        sender != null ? sender.to_full_display() : "",
                        Util.Email.strip_subject_prefixes(email),
                        email.properties != null
                            ? email.properties.date_received.to_unix() * 1000000 : 0
                    );
                }
            }
        } catch (GLib.Error error) {
            if (!request.is_cancelled()) debug("Tray metadata not cached: %s", error.message);
        }
        if (this.requests.get(key) == request) this.requests.unset(key);
    }

    private void on_watcher_appeared(GLib.DBusConnection connection,
                                     string name, string owner) {
        connection.call.begin(
            name, "/StatusNotifierWatcher", "org.kde.StatusNotifierWatcher",
            "RegisterStatusNotifierItem", new GLib.Variant("(s)", this.bus_name),
            null, NONE, -1, this.cancellable, (obj, res) => {
                try { connection.call.end(res); }
                catch (GLib.Error error) {
                    if (!this.cancellable.is_cancelled())
                        debug("Tray registration unavailable: %s", error.message);
                }
            }
        );
    }
}

internal struct Application.TrayPixmap {
    public int width;
    public int height;
    public uint8[] pixels;
}

internal struct Application.TrayTooltip {
    public string icon;
    public TrayPixmap[] pixmaps;
    public string title;
    public string description;
}

[DBus (name = "org.kde.StatusNotifierItem")]
internal class Application.TrayItem : GLib.Object {
    public string category { owned get { return "Communications"; } }
    public string id { owned get { return Config.APP_ID; } }
    public string title { owned get {
        return this.new_mail_count > 0 ? "Convey — " + count_description() : "Convey";
    } }
    public string status { owned get { return "Active"; } }
    public int window_id { get { return 0; } }
    public string icon_name { owned get { return Config.APP_ID + "-tray"; } }
    public string icon_theme_path { owned get { return ""; } }
    public TrayPixmap[] icon_pixmap { owned get { return {}; } }
    public string overlay_icon_name { owned get { return ""; } }
    public TrayPixmap[] overlay_icon_pixmap { owned get { return {}; } }
    public string attention_icon_name { owned get { return this.icon_name; } }
    public TrayPixmap[] attention_icon_pixmap { owned get { return {}; } }
    public string attention_movie_name { owned get { return ""; } }
    public bool item_is_menu { get { return false; } }
    public GLib.ObjectPath menu { owned get { return new GLib.ObjectPath("/StatusNotifierItem/Menu"); } }
    public TrayTooltip tool_tip { owned get {
        return { this.icon_name, {}, "Convey", count_description() };
    } }
    public string x_ayatana_label { owned get {
        return this.new_mail_count > 999 ? "999+"
            : this.new_mail_count > 0 ? this.new_mail_count.to_string() : "";
    } }
    public string x_ayatana_label_guide { owned get { return "999+"; } }
    public signal void x_ayatana_new_label(string label, string guide);
    public signal void new_title();
    public signal void new_tool_tip();
    private int new_mail_count = 0;

    internal void set_new_mail_count(int count) {
        count = int.max(0, count);
        if (count == this.new_mail_count) return;
        this.new_mail_count = count;
        notify_property("title");
        notify_property("tool-tip");
        notify_property("x-ayatana-label");
        new_title();
        new_tool_tip();
        x_ayatana_new_label(this.x_ayatana_label, this.x_ayatana_label_guide);
    }
    private string count_description() {
        return this.new_mail_count > 0
            ? ngettext("%u new message", "%u new messages", this.new_mail_count).printf(this.new_mail_count)
            : _("No new mail");
    }

    private string activation_token = "";
    internal signal void open_requested(string token);
    internal signal void compose_requested();
    internal signal void quit_requested();
    internal signal void email_requested(GLib.Variant target);

    public void activate(int x, int y) throws GLib.DBusError, GLib.IOError {
        request_open();
    }
    internal void request_open() {
        string token = this.activation_token;
        this.activation_token = "";
        open_requested(token);
    }
    public void secondary_activate(int x, int y) throws GLib.DBusError, GLib.IOError {
        request_compose();
    }
    internal void request_compose() {
        this.activation_token = "";
        compose_requested();
    }
    public void x_ayatana_secondary_activate(uint timestamp) throws GLib.DBusError, GLib.IOError {
        secondary_activate(0, 0);
    }
    public void provide_xdg_activation_token(string token) throws GLib.DBusError, GLib.IOError {
        this.activation_token = token;
    }
    public void context_menu(int x, int y) throws GLib.DBusError, GLib.IOError {
        // The panel renders the exported DBusMenu itself.
    }
    public void scroll(int delta, string orientation) throws GLib.DBusError, GLib.IOError {}
}

internal struct Application.TrayMenuLayout {
    public int id;
    public GLib.HashTable<string,GLib.Variant> properties;
    public GLib.Variant[] children;
}
internal struct Application.TrayMenuProperties {
    public int id;
    public GLib.HashTable<string,GLib.Variant> properties;
}
internal struct Application.TrayMenuEvent {
    public int id;
    public string event_id;
    public GLib.Variant data;
    public uint timestamp;
}

/** Event-driven menu; mail IDs are stable and never reused in this process. */
[DBus (name = "com.canonical.dbusmenu")]
internal class Application.TrayMenu : GLib.Object {
    public uint version { get { return 3; } }
    public string text_direction { owned get { return "ltr"; } }
    public string status { owned get { return "normal"; } }
    public string[] icon_theme_path { owned get { return {}; } }
    internal signal void selected(int id);
    internal signal void mail_selected(GLib.Variant target);
    public signal void layout_updated(uint revision, int parent);
    private uint current_revision = 1;
    private int new_mail_count = 0;
    private string fingerprint = "";
    private Gee.List<TrayMailEntry> messages = new Gee.ArrayList<TrayMailEntry>();

    internal void set_new_mail(int count, Gee.List<TrayMailEntry> messages) {
        var state = new GLib.StringBuilder(count.to_string());
        foreach (var message in messages) state.append_printf("\n%d:%s", message.menu_id, message.label);
        if (this.fingerprint == state.str) return;
        this.fingerprint = state.str;
        this.new_mail_count = count;
        this.messages = messages;
        this.current_revision++;
        layout_updated(this.current_revision, 0);
    }

    private TrayMailEntry? find_message(int id) {
        foreach (var message in this.messages) if (message.menu_id == id) return message;
        return null;
    }

    private int[] menu_ids() {
        int[] ids = {1, 2, 3, 5};
        foreach (var message in this.messages) ids += message.menu_id;
        if (this.new_mail_count > this.messages.size) ids += 7;
        ids += 6;
        ids += 4;
        return ids;
    }

    private bool exists(int id) { return (id >= 0 && id <= 6) ||
        (id == 7 && this.new_mail_count > this.messages.size) || find_message(id) != null; }

    private GLib.HashTable<string,GLib.Variant> properties_for(int id, string[] names) {
        var all = new GLib.HashTable<string,GLib.Variant>(str_hash, str_equal);
        all.insert("visible", new GLib.Variant.boolean(true));
        var message = find_message(id);
        all.insert("enabled", new GLib.Variant.boolean(
            id == 0 || id == 1 || id == 2 || id == 4 || message != null
        ));
        if (id == 0) {
            all.insert("children-display", new GLib.Variant.string("submenu"));
        } else if (id == 3 || id == 6) {
            all.insert("type", new GLib.Variant.string("separator"));
        } else if (id == 5 || id == 7) {
            int count = id == 7 ? this.new_mail_count - this.messages.size : this.new_mail_count;
            string label = count > 0
                ? ngettext("%u new message", "%u new messages", count).printf(count)
                : _("No new mail");
            if (id == 7) label = "+ " + label;
            all.insert("label", new GLib.Variant.string(label));
        } else if (message != null) {
            string label = message.label.char_count() > 100
                ? message.label.substring(0, message.label.index_of_nth_char(97)) + "…"
                : message.label;
            all.insert("label", new GLib.Variant.string(label.replace("_", "__")));
            all.insert("icon-name", new GLib.Variant.string("mail-unread-symbolic"));
        } else {
            string label = id == 1 ? _("Open Convey")
                : id == 2 ? _("New Message") : _("_Quit");
            all.insert("label", new GLib.Variant.string(label));
            all.insert("icon-name", new GLib.Variant.string(id == 1
                ? "mail-unread-symbolic" : id == 2
                ? "mail-message-new-symbolic" : "application-exit-symbolic"));
        }
        if (names.length == 0) return all;
        var filtered = new GLib.HashTable<string,GLib.Variant>(str_hash, str_equal);
        foreach (string name in names) {
            GLib.Variant? value = all.lookup(name);
            if (value != null) filtered.insert(name, value);
        }
        return filtered;
    }

    public void get_layout(int parent_id, int recursion_depth, string[] property_names,
                           out uint revision, out TrayMenuLayout layout)
        throws GLib.DBusError, GLib.IOError {
        if (!exists(parent_id)) throw new GLib.DBusError.INVALID_ARGS("Unknown menu item");
        revision = this.current_revision;
        GLib.Variant[] children = {};
        if (parent_id == 0 && recursion_depth != 0) {
            foreach (int id in menu_ids()) {
                children += new GLib.Variant("(i@a{sv}@av)", id,
                    properties_variant(properties_for(id, property_names)),
                    new GLib.Variant.array(GLib.VariantType.VARIANT, {}));
            }
        }
        layout = { parent_id, properties_for(parent_id, property_names), children };
    }

    private GLib.Variant properties_variant(GLib.HashTable<string,GLib.Variant> props) {
        var builder = new GLib.VariantBuilder(new GLib.VariantType("a{sv}"));
        props.foreach((key, value) => builder.add("{sv}", key, value));
        return builder.end();
    }

    public TrayMenuProperties[] get_group_properties(int[] ids, string[] property_names)
        throws GLib.DBusError, GLib.IOError {
        TrayMenuProperties[] result = {};
        foreach (int id in ids) {
            if (exists(id)) {
                TrayMenuProperties entry = { id, properties_for(id, property_names) };
                result += entry;
            }
        }
        return result;
    }

    public new GLib.Variant get_property(int id, string name) throws GLib.DBusError, GLib.IOError {
        if (!exists(id)) throw new GLib.DBusError.INVALID_ARGS("Unknown menu item");
        var properties = properties_for(id, {});
        GLib.Variant? value = properties.lookup(name);
        if (value == null) throw new GLib.DBusError.INVALID_ARGS("Unknown menu property");
        return value;
    }

    public void event(int id, string event_id, GLib.Variant data, uint timestamp)
        throws GLib.DBusError, GLib.IOError {
        if (event_id == "clicked" && (id == 1 || id == 2 || id == 4)) selected(id);
        else if (event_id == "clicked") {
            var message = find_message(id);
            if (message != null) mail_selected(message.target);
        }
    }

    public int[] event_group(TrayMenuEvent[] events) throws GLib.DBusError, GLib.IOError {
        int[] errors = {};
        foreach (var item in events) {
            if (!exists(item.id)) errors += item.id;
            else event(item.id, item.event_id, item.data, item.timestamp);
        }
        return errors;
    }

    public bool about_to_show(int id) throws GLib.DBusError, GLib.IOError { return false; }
    public void about_to_show_group(int[] ids, out int[] updates, out int[] errors)
        throws GLib.DBusError, GLib.IOError {
        updates = {};
        int[] invalid = {};
        foreach (int id in ids) if (!exists(id)) invalid += id;
        errors = invalid;
    }
}
