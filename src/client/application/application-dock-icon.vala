/* New downstream file: 2026-10-28. GPL-3.0-only; see COPYING. */

/** GNOME docks resolve icons from desktop files, not Gtk.Window.icon_name.
 * Publish an app-owned session icon through the ordinary XDG icon theme.
 * The temporary launcher retains the installed entry's ID and commands.
 * A user's own launcher is never overwritten. */
internal class Application.DockIcon : GLib.Object {
    private const string MARKER = "X-GriassDiMail-SessionIcon";
    private string? launcher = null;
    private GLib.KeyFile? desktop = null;
    private string theme;
    private string icon_name = Config.APP_ID + "-session";
    private bool? opened = null;
    private uint64 last_mtime = 0;
    private string? last_launcher_content = null;

    internal DockIcon(string? data_home = null, string? installed_launcher = null) {
        string data = data_home ?? GLib.Environment.get_user_data_dir();
        this.theme = GLib.Path.build_filename(data, "icons", "hicolor");
        string path = GLib.Path.build_filename(data, "applications", Config.APP_ID + ".desktop");
        try {
            if (GLib.FileUtils.test(path, EXISTS)) {
                var existing = new GLib.KeyFile();
                existing.load_from_file(path, NONE);
                if (!existing.has_key("Desktop Entry", MARKER) ||
                    !existing.get_boolean("Desktop Entry", MARKER)) return;
                GLib.FileUtils.get_contents(path, out this.last_launcher_content);
            }
            string? source = installed_launcher;
            if (source == null) {
                foreach (string directory in GLib.Environment.get_system_data_dirs()) {
                    string candidate = GLib.Path.build_filename(directory, "applications", Config.APP_ID + ".desktop");
                    if (GLib.FileUtils.test(candidate, IS_REGULAR)) {
                        source = candidate;
                        break;
                    }
                }
            }
            if (source == null) return;
            this.desktop = new GLib.KeyFile();
            this.desktop.load_from_file(source, KEEP_TRANSLATIONS | KEEP_COMMENTS);
            this.desktop.set_string("Desktop Entry", "Icon", this.icon_name);
            this.desktop.set_boolean("Desktop Entry", MARKER, true);
            GLib.DirUtils.create_with_parents(GLib.Path.get_dirname(path), 0755);
            this.launcher = path;
            set_new_mail(false);
        } catch (GLib.Error error) {
            debug("Dynamic dock icon unavailable: %s", error.message);
        }
    }

    internal void set_new_mail(bool has_mail) {
        if (this.launcher == null || this.desktop == null || this.opened == has_mail) return;
        try {
            // The desktop entry may have been edited or replaced while running.
            // In that case relinquish it before changing icons or the launcher.
            if (GLib.FileUtils.test(this.launcher, EXISTS)) {
                string current;
                GLib.FileUtils.get_contents(this.launcher, out current);
                if (current != this.last_launcher_content) {
                    this.launcher = null;
                    return;
                }
            } else if (this.last_launcher_content != null) {
                this.launcher = null;
                return;
            }
            var image = new Gdk.Pixbuf.from_resource(
                Client.RESOURCE_BASE_PATH + (has_mail ? "/brand/envelope-open.png" : "/brand/envelope-closed.png")
            );
            foreach (int size in new int[] {16, 24, 32, 48, 64, 128, 256, 512}) {
                string directory = GLib.Path.build_filename(this.theme, "%dx%d".printf(size, size), "apps");
                GLib.DirUtils.create_with_parents(directory, 0755);
                var scaled = image.scale_simple(size, size, Gdk.InterpType.HYPER);
                scaled.save(GLib.Path.build_filename(directory, this.icon_name + ".png"), "png");
            }
            // Theme lookup caches use second-resolution directory mtimes.
            // A desktop entry update asks GNOME to rescan the changed theme.
            uint64 now = (uint64) (GLib.get_real_time() / 1000000);
            this.last_mtime = uint64.max(now, this.last_mtime + 1);
            GLib.File.new_for_path(this.theme).set_attribute_uint64(
                GLib.FileAttribute.TIME_MODIFIED, this.last_mtime, NONE
            );
            this.desktop.set_string("Desktop Entry", "X-GriassDiMail-MailState", has_mail ? "new" : "empty");
            string content = this.desktop.to_data();
            GLib.FileUtils.set_contents(this.launcher, content);
            this.last_launcher_content = content;
            this.opened = has_mail;
        } catch (GLib.Error error) {
            debug("Could not update dock icon: %s", error.message);
        }
    }

    internal void close() {
        set_new_mail(false);
        if (this.launcher == null) return;
        try {
            var current = new GLib.KeyFile();
            current.load_from_file(this.launcher, NONE);
            // Leave any user edit made during the session untouched.
            if (current.to_data() == this.desktop.to_data())
                GLib.FileUtils.unlink(this.launcher);
        } catch (GLib.Error error) {
            debug("Session launcher already unavailable: %s", error.message);
        }
        this.launcher = null;
    }
}
