/*
 * Copyright © 2016 Software Freedom Conservancy Inc.
 * Copyright © 2019-2020 Michael Gratton <mike@vee.net>.
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

[ModuleInit]
public void peas_register_types(TypeModule module) {
    Peas.ObjectModule obj = module as Peas.ObjectModule;
    obj.register_extension_type(
        typeof(Plugin.PluginBase),
        typeof(Plugin.DesktopNotifications)
    );
}

/**
 * Manages standard desktop application notifications.
 */
public class Plugin.DesktopNotifications :
    PluginBase,
    NotificationExtension,
    FolderExtension,
    EmailExtension,
    TrustedExtension {


    private const Convey.Folder.SpecialUse[] MONITORED_TYPES = {
        INBOX, NONE
    };

    public NotificationContext notifications {
        get; set construct;
    }

    public FolderContext folders {
        get; set construct;
    }

    public EmailContext email {
        get; set construct;
    }

    public global::Application.Client client_application {
        get; set construct;
    }

    public global::Application.PluginManager client_plugins {
        get; set construct;
    }

    private const string ARRIVED_ID = "email-arrived";

    private EmailStore? email_store = null;
    private GLib.Notification? arrived_notification = null;
    private GLib.Cancellable? cancellable = null;


    public override async void activate(bool is_startup) throws GLib.Error {
        this.cancellable = new GLib.Cancellable();
        this.email_store = yield this.email.get_email_store();

        this.notifications.new_messages_arrived.connect(on_new_messages_arrived);
        this.notifications.new_messages_retired.connect(on_new_messages_retired);

        FolderStore folder_store = yield this.folders.get_folder_store();
        folder_store.folders_available.connect(
            (folders) => check_folders(folders)
        );
        folder_store.folders_unavailable.connect(
                (folders) => check_folders(folders)
        );
        folder_store.folders_type_changed.connect(
            (folders) => check_folders(folders)
        );
        check_folders(folder_store.get_folders());
    }

    public override async void deactivate(bool is_shutdown) throws GLib.Error {
        this.cancellable.cancel();

        // Keep existing notifications if shutting down since they are
        // persistent, but revoke if the plugin is being disabled.
        if (!is_shutdown) {
            clear_arrived_notification();
        }
    }

    private void clear_arrived_notification() {
        this.client_application.withdraw_notification(ARRIVED_ID);
        this.arrived_notification = null;
    }

    private async void notify_specific_message(Folder folder,
                                               int total,
                                               Email email
    ) throws GLib.Error {
        string title = to_notitication_title(folder.account, total);
        GLib.Icon? icon = null;
        Convey.RFC822.MailboxAddress? originator = email.get_primary_originator();
        if (originator != null) {
            ContactStore contacts =
                yield this.notifications.get_contacts_for_folder(folder);
            global::Application.Contact? contact = yield contacts.load(
                originator, this.cancellable
            );

            title = (
                contact.is_trusted
                ? contact.display_name
                : originator.to_short_display()
            );

            icon = contact.avatar;
        }

        string body = Util.Email.strip_subject_prefixes(email);
        if (total > 1) {
            body = ngettext(
                /// Notification body when a message as been received
                /// and other unread messages have not been
                /// seen. First string substitution is the message
                /// subject and the second is the number of unseen
                /// messages
                "%s\n(%d other new message)",
                "%s\n(%d other new messages)",
                total - 1
            ).printf(
                body,
                total - 1
            );
        }

        Gdk.Texture texture;
        if (icon != null) {
            int size = avatar_size();
            var icon_stream = yield ((LoadableIcon) icon).load_async(size, null);
            var pixbuf = yield new Gdk.Pixbuf.from_stream_at_scale_async(
                icon_stream, size, size, false
            );
            texture = round_texture(Gdk.Texture.for_pixbuf(pixbuf));
        } else {
            texture = generate_fallback_avatar(title);
        }

        issue_arrived_notification(title, body, texture, folder, email.identifier);
    }

    // Clip the contact photo to a circle, matching the shape of the
    // Adw.Avatar fallback
    private Gdk.Texture round_texture(Gdk.Texture square) {
        int size = square.get_width();
        Gsk.Renderer renderer = new Gsk.CairoRenderer();
        try {
            renderer.realize(null);
        } catch (GLib.Error error) {
            warning("Couldn't realize Cairo renderer: %s", error.message);
            return square;
        }

        var bounds = Graphene.Rect() {
            origin = Graphene.Point() { x = 0, y = 0 },
            size = Graphene.Size() { width = size, height = size }
        };
        var circle = Gsk.RoundedRect();
        circle.init_from_rect(bounds, size / 2.0f);

        var snapshot = new Gtk.Snapshot();
        snapshot.push_rounded_clip(circle);
        snapshot.append_texture(square, bounds);
        snapshot.pop();

        Gdk.Texture rounded = renderer.render_texture(snapshot.to_node(), null);
        renderer.unrealize();
        return rounded;
    }

    // Adwaita's avatar hues. Adw.Avatar can't be rendered here (it needs
    // to live inside a window), so the flat tint from style.css is drawn by
    // hand with the same mix; keep the two in step.
    private const string[] AVATAR_HUES = {
        "#337fdc", "#0f9ac8", "#29ae74", "#6ab85b", "#d29d09", "#d68400",
        "#ed5b00", "#e62d42", "#e33b6a", "#9945b5", "#7a59ca", "#b08952",
        "#785336", "#6e6d71"
    };

    // Notification icons are shown at 48px, so render that at whatever the
    // sharpest attached monitor scales it to
    private const int AVATAR_LOGICAL_SIZE = 48;

    private int avatar_size() {
        double scale = 1;
        Gdk.Display? display = Gdk.Display.get_default();
        if (display != null) {
            var monitors = display.get_monitors();
            for (uint i = 0; i < monitors.get_n_items(); i++) {
                var monitor = (Gdk.Monitor) monitors.get_item(i);
                // Under fractional scaling the shell still composites at
                // the (larger) integer factor, so take whichever is bigger
                scale = double.max(
                    scale,
                    double.max(monitor.get_scale(), monitor.get_scale_factor())
                );
            }
        }
        return (int) Math.ceil(AVATAR_LOGICAL_SIZE * scale);
    }

    private Gdk.Texture generate_fallback_avatar(string title) {
        int size = avatar_size();

        // Adw.Avatar picks its colour the same way
        Gdk.RGBA hue = Gdk.RGBA();
        hue.parse(AVATAR_HUES[title.hash() % AVATAR_HUES.length]);

        // Same mix as style.css, against the same theme colours, so the
        // notification and the message list agree
        Gdk.RGBA bg = mix(hue, theme_color("view_bg_color", "#ffffff"), 0.22);
        Gdk.RGBA text = mix(hue, theme_color("window_fg_color", "#000000"), 0.58);

        var surface = new Cairo.ImageSurface(Cairo.Format.ARGB32, size, size);
        var cr = new Cairo.Context(surface);

        cr.arc(size / 2.0, size / 2.0, size / 2.0, 0, 2 * Math.PI);
        cr.set_source_rgb(bg.red, bg.green, bg.blue);
        cr.fill();

        string initials = avatar_initials(title);
        if (initials != "") {
            cr.set_source_rgb(text.red, text.green, text.blue);
            cr.select_font_face(
                ui_font_family(), Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD
            );
            cr.set_font_size(size * 0.4);
            Cairo.TextExtents extents;
            cr.text_extents(initials, out extents);
            cr.move_to(
                size / 2.0 - extents.width / 2 - extents.x_bearing,
                size / 2.0 - extents.height / 2 - extents.y_bearing
            );
            cr.show_text(initials);
        }
        surface.flush();

        unowned uint8[] data = surface.get_data();
        data.length = surface.get_stride() * size;
        return new Gdk.MemoryTexture(
            size, size, Gdk.MemoryFormat.B8G8R8A8_PREMULTIPLIED,
            new GLib.Bytes(data), surface.get_stride()
        );
    }

    private Gdk.RGBA theme_color(string name, string fallback) {
        Gdk.RGBA color = Gdk.RGBA();
        // lookup_color is deprecated, but nothing else resolves libadwaita's
        // named colours without a rendered widget
        if (!new Gtk.Label(null).get_style_context().lookup_color(name, out color)) {
            color.parse(fallback);
        }
        return color;
    }

    private Gdk.RGBA mix(Gdk.RGBA a, Gdk.RGBA b, double amount) {
        return Gdk.RGBA() {
            red = (float) (a.red * amount + b.red * (1 - amount)),
            green = (float) (a.green * amount + b.green * (1 - amount)),
            blue = (float) (a.blue * amount + b.blue * (1 - amount)),
            alpha = 1
        };
    }

    // The font the rest of the UI is drawn in, so the initials match
    private string ui_font_family() {
        Gtk.Settings? settings = Gtk.Settings.get_default();
        if (settings != null && settings.gtk_font_name != null) {
            string? family = Pango.FontDescription.from_string(
                settings.gtk_font_name
            ).get_family();
            if (family != null) {
                return family;
            }
        }
        return "sans-serif";
    }

    // First and last word's initial, as Adw.Avatar does
    private string avatar_initials(string title) {
        var words = new Gee.ArrayList<string>();
        foreach (string word in title.strip().split(" ")) {
            if (word != "") {
                words.add(word);
            }
        }
        if (words.is_empty) {
            return "";
        }
        var initials = new GLib.StringBuilder();
        initials.append_unichar(words[0].get_char().toupper());
        if (words.size > 1) {
            initials.append_unichar(words[words.size - 1].get_char().toupper());
        }
        return initials.str;
    }

    private void notify_general(Folder folder, int total, int added) {
        GLib.Icon icon = new GLib.ThemedIcon("%s-symbolic".printf(Config.APP_ID));
        string title = to_notitication_title(folder.account, total);
        string body = ngettext(
            /// Notification body when multiple messages have been
            /// received at the same time and other unseen messages
            /// exist. String substitution is the number of new
            /// messages that have arrived.
            "%d new message", "%d new messages", added
        ).printf(added);
        if (total > added) {
            body = ngettext(
                /// Notification body when multiple messages have been
                /// received at the same time and some unseen messages
                /// already exist. String substitution is the message
                /// above with the number of new messages that have
                /// arrived, number substitution is the total number
                /// of unseen messages.
                "%s, %d new message total",
                "%s, %d new messages total",
                total
            ).printf(body, total);
        }

        issue_arrived_notification(title, body, icon, folder, null);
    }

    private void issue_arrived_notification(string summary,
                                            string body,
                                            GLib.Icon icon,
                                            Folder folder,
                                            EmailIdentifier? id) {
        // only one outstanding notification at a time
        clear_arrived_notification();

        string? action = null;
        GLib.Variant? target_param = null;
        if (id == null) {
            action = Action.Application.SHOW_FOLDER;
            target_param = folder.to_variant();
        } else {
            action = Action.Application.SHOW_EMAIL;
            target_param = id.to_variant();
        }

        this.arrived_notification = issue_notification(
            ARRIVED_ID,
            summary,
            body,
            icon,
            Action.Application.prefix(action),
            target_param
        );
    }

    private GLib.Notification issue_notification(string id,
                                                 string summary,
                                                 string body,
                                                 GLib.Icon icon,
                                                 string? action,
                                                 GLib.Variant? action_target) {
        GLib.Notification notification = new GLib.Notification(summary);
        notification.set_body(body);
        notification.set_icon(icon);

        // Do not show notification actions under Unity, it's
        // notifications daemon doesn't support them.
        if (this.client_application.config.desktop_environment == UNITY) {
            this.client_application.send_notification(id, notification);
            return notification;
        } else {
            if (action != null) {
                notification.set_default_action_and_target_value(
                    action, action_target
                );
            }

            this.client_application.send_notification(id, notification);
            return notification;
        }
    }

    private async void handle_new_messages(Folder folder,
                                           int total,
                                           Gee.Collection<EmailIdentifier> added) {
        if (this.notifications.should_notify_new_messages(folder)) {
            // notify about a specific message if it's the only one
            // present and it can be loaded, otherwise notify
            // generally
            bool notified = false;
            try {
                Email? message = Convey.Collection.first(
                    yield this.email_store.get_email(
                        Convey.Collection.single(Convey.Collection.first(added)),
                        this.cancellable
                    )
                );
                if (message != null) {
                    yield notify_specific_message(folder, total, message);
                    notified = true;
                } else {
                    warning("Could not load email for notification");
                }
            } catch (GLib.Error error) {
                warning("Error loading email for notification: %s", error.message);
            }

            if (!notified) {
                notify_general(folder, total, added.size);
            }
        }
    }

    private void check_folders(Gee.Collection<Folder> folders) {
        foreach (Folder folder in folders) {
            if (folder.used_as in MONITORED_TYPES) {
                this.notifications.start_monitoring_folder(folder);
            } else {
                this.notifications.stop_monitoring_folder(folder);
            }
        }
    }

    private inline string to_notitication_title(Account account, int count) {
        return ngettext(
            /// Notification title when new messages have been
            /// received
            "New message", "New messages", count
        );
    }

    private void on_new_messages_arrived(Folder folder,
                                         int total,
                                         Gee.Collection<EmailIdentifier> added) {
        this.handle_new_messages.begin(folder, total, added);
    }

    private void on_new_messages_retired(Folder folder, int total) {
        clear_arrived_notification();
    }

}
