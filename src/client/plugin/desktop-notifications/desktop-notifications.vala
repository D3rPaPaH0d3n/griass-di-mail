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
            var icon_stream = yield ((LoadableIcon) icon).load_async(32, null);
            var pixbuf = yield new Gdk.Pixbuf.from_stream_at_scale_async(icon_stream, 32, 32, false);
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

    // Adw.Avatar's palette, as "gradient-top gradient-bottom text". Neither
    // Adw.Avatar.draw_to_texture() nor snapshotting the widget works here,
    // since both need the avatar to live inside a window, so the same look
    // is drawn by hand instead.
    private const string[] AVATAR_COLORS = {
        "#83b6ec #337fdc #cfe1f5",
        "#7ad9f1 #0f9ac8 #caeaf2",
        "#8de6b1 #29ae74 #cef8d8",
        "#b5e98a #6ab85b #e6f9d7",
        "#f8e359 #d29d09 #f9f4e1",
        "#ffcb62 #d68400 #ffead1",
        "#ffa95a #ed5b00 #ffe5c5",
        "#f78773 #e62d42 #f8d2ce",
        "#e973ab #e33b6a #fac7de",
        "#cb78d4 #9945b5 #e7c2e8",
        "#9e91e8 #7a59ca #d5d2f5",
        "#e3cf9c #b08952 #f2eade",
        "#be916d #785336 #e5d6ca",
        "#c0bfbc #6e6d71 #d8d7d3"
    };

    private Gdk.Texture generate_fallback_avatar(string title) {
        const int SIZE = 32;

        // Adw.Avatar picks its colour the same way
        string[] colors =
            AVATAR_COLORS[title.hash() % AVATAR_COLORS.length].split(" ");
        Gdk.RGBA top = Gdk.RGBA(), bottom = Gdk.RGBA(), text = Gdk.RGBA();
        top.parse(colors[0]);
        bottom.parse(colors[1]);
        text.parse(colors[2]);

        var surface = new Cairo.ImageSurface(Cairo.Format.ARGB32, SIZE, SIZE);
        var cr = new Cairo.Context(surface);

        var gradient = new Cairo.Pattern.linear(0, 0, 0, SIZE);
        gradient.add_color_stop_rgb(0, top.red, top.green, top.blue);
        gradient.add_color_stop_rgb(1, bottom.red, bottom.green, bottom.blue);
        cr.arc(SIZE / 2.0, SIZE / 2.0, SIZE / 2.0, 0, 2 * Math.PI);
        cr.set_source(gradient);
        cr.fill();

        string initials = avatar_initials(title);
        if (initials != "") {
            cr.set_source_rgb(text.red, text.green, text.blue);
            cr.select_font_face(
                ui_font_family(), Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD
            );
            cr.set_font_size(SIZE * 0.4);
            Cairo.TextExtents extents;
            cr.text_extents(initials, out extents);
            cr.move_to(
                SIZE / 2.0 - extents.width / 2 - extents.x_bearing,
                SIZE / 2.0 - extents.height / 2 - extents.y_bearing
            );
            cr.show_text(initials);
        }
        surface.flush();

        unowned uint8[] data = surface.get_data();
        data.length = surface.get_stride() * SIZE;
        return new Gdk.MemoryTexture(
            SIZE, SIZE, Gdk.MemoryFormat.B8G8R8A8_PREMULTIPLIED,
            new GLib.Bytes(data), surface.get_stride()
        );
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
