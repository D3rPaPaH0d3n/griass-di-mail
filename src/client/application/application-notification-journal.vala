/* New downstream file: 2026-10-28. GPL-3.0-only; see COPYING. */

/** Private recovery list containing only IDs of this plugin's mail popups. */
public class Application.NotificationJournal : GLib.Object {
    private const string PREFIX = "email-arrived-";
    private GLib.File file;
    private Gee.HashSet<string> ids = new Gee.HashSet<string>();

    public NotificationJournal(GLib.File file) throws GLib.Error {
        this.file = file;
        var parent = file.get_parent();
        if (parent == null || parent.get_path() == null) {
            throw new GLib.IOError.INVALID_ARGUMENT("A local journal path is required");
        }
        if (GLib.DirUtils.create_with_parents(parent.get_path(), 0700) != 0) {
            throw new GLib.IOError.FAILED("Cannot create notification journal directory");
        }
        try {
            var info = file.query_info(GLib.FileAttribute.STANDARD_SIZE, NONE);
            if (info.get_size() > 4 * 1024 * 1024) {
                throw new GLib.IOError.INVALID_DATA("Notification journal is too large");
            }
            uint8[] data;
            file.load_contents(null, out data, null);
            var values = new GLib.KeyFile();
            values.load_from_data((string) data, data.length, NONE);
            foreach (string id in values.get_string_list("Mail", "ids")) {
                if (is_mail_id(id)) this.ids.add(id);
            }
        } catch (GLib.IOError.NOT_FOUND error) {
            // A new installation has no popup recovery history.
        }
    }

    public static bool is_mail_id(string id) {
        return id.has_prefix(PREFIX) && id.length > PREFIX.length &&
            id.length <= 8192 && !id.contains("\n") && !id.contains("\r");
    }

    public Gee.Collection<string> get_ids() {
        var copy = new Gee.ArrayList<string>();
        copy.add_all(this.ids);
        return copy;
    }

    /** Persist before sending, so a crash cannot leave an untracked popup. */
    public void record(string id) throws GLib.Error {
        if (!is_mail_id(id)) {
            throw new GLib.IOError.INVALID_ARGUMENT("Not a mail notification ID");
        }
        if (this.ids.contains(id)) return;
        if (this.ids.size >= 10000) {
            throw new GLib.IOError.NO_SPACE("Notification journal is full");
        }
        this.ids.add(id);
        try {
            save();
        } catch (GLib.Error error) {
            this.ids.remove(id);
            throw error;
        }
    }

    /** Call only after withdrawing the popup. A stale disk entry is harmless. */
    public void forget(string id) throws GLib.Error {
        if (this.ids.remove(id)) save();
    }

    public void clear() throws GLib.Error {
        this.ids.clear();
        save();
    }

    private void save() throws GLib.Error {
        var values = new GLib.KeyFile();
        values.set_string_list("Mail", "ids", this.ids.to_array());
        string data = values.to_data();
        this.file.replace_contents(
            data.data, null, false,
            GLib.FileCreateFlags.PRIVATE | GLib.FileCreateFlags.REPLACE_DESTINATION,
            null, null
        );
    }
}

/** Invalidates asynchronous popup work when a folder's unseen set changes. */
public class Application.NotificationDeliveryGuard : GLib.Object {
    private Gee.HashMap<string, int64?> generations = new Gee.HashMap<string, int64?>();

    public int64 capture(string folder) {
        return this.generations.get(folder) ?? 0;
    }

    public void invalidate(string folder) {
        this.generations.set(folder, capture(folder) + 1);
    }

    public bool is_current(string folder, int64 generation, GLib.Cancellable cancellable) {
        return !cancellable.is_cancelled() && capture(folder) == generation;
    }
}
