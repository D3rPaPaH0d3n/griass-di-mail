/* Downstream modification: 2026-10-28 — session-scoped popup recovery and async retirement guard. */
/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Downstream modification: 2026-10-26 — mail-specific popup action targets and buttons. */
/*
 * Copyright © 2016 Software Freedom Conservancy Inc.
 * Copyright © 2019-2020 Michael Gratton <mike@vee.net>.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
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


    private const GriabuntuMail.Folder.SpecialUse[] MONITORED_TYPES = {
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
    private const int MAX_INDIVIDUAL = 3;

    private EmailStore? email_store = null;
    private FolderStore? folder_store = null;
    private Gee.HashMultiMap<string, string> arrived =
        new Gee.HashMultiMap<string, string>();
    private GLib.Cancellable? cancellable = null;
    private global::Application.NotificationJournal? journal = null;
    private global::Application.NotificationDeliveryGuard delivery =
        new global::Application.NotificationDeliveryGuard();


    public override async void activate(bool is_startup) throws GLib.Error {
        this.cancellable = new GLib.Cancellable();
        var activation = this.cancellable;
        this.journal = null;
        try {
            this.journal = new global::Application.NotificationJournal(
                this.client_application.get_home_data_directory()
                    .get_child("notifications").get_child("mail-popups.ini")
            );
            withdraw_all_arrived();
        } catch (GLib.Error error) {
            // Monitoring also drives the shared new-mail count. A broken
            // journal suppresses popups, but must not disable that monitor.
            this.journal = null;
            this.arrived.clear();
            warning("Mail popups disabled because their recovery journal is unavailable");
        }
        this.email_store = yield this.email.get_email_store();
        if (activation.is_cancelled()) return;

        this.notifications.new_messages_arrived.connect(on_new_messages_arrived);
        this.notifications.new_messages_retired.connect(on_new_messages_retired);
        this.notifications.email_seen.connect(on_email_seen);

        this.folder_store = yield this.folders.get_folder_store();
        if (activation.is_cancelled()) return;
        this.folder_store.folders_available.connect(check_folders);
        this.folder_store.folders_unavailable.connect(on_folders_unavailable);
        this.folder_store.folders_type_changed.connect(check_folders);
        check_folders(this.folder_store.get_folders());
    }

    public override async void deactivate(bool is_shutdown) throws GLib.Error {
        if (this.cancellable != null) this.cancellable.cancel();
        this.notifications.new_messages_arrived.disconnect(on_new_messages_arrived);
        this.notifications.new_messages_retired.disconnect(on_new_messages_retired);
        this.notifications.email_seen.disconnect(on_email_seen);
        if (this.folder_store != null) {
            this.folder_store.folders_available.disconnect(check_folders);
            this.folder_store.folders_unavailable.disconnect(on_folders_unavailable);
            this.folder_store.folders_type_changed.disconnect(check_folders);
        }
        try {
            withdraw_all_arrived();
        } catch (GLib.Error error) {
            // Retained IDs can be recovered on the next successful startup.
            this.arrived.clear();
            warning("Could not clear mail notification recovery journal");
        }
    }

    private void withdraw_all_arrived() throws GLib.Error {
        // Recovery includes only IDs we recorded ourselves, never error or
        // other application notifications. Retire these on clean shutdown too.
        if (this.journal != null) {
            foreach (string id in this.journal.get_ids()) {
                this.client_application.withdraw_notification(id);
            }
            this.journal.clear();
        }
        this.arrived.clear();
    }

    private void withdraw_arrived(string id) {
        this.client_application.withdraw_notification(id);
        try {
            if (this.journal != null) this.journal.forget(id);
        } catch (GLib.Error error) {
            warning("Could not update mail notification recovery journal");
        }
    }

    private bool delivery_current(Folder folder, int64 generation,
                                  GLib.Cancellable request) {
        return this.cancellable == request &&
            this.delivery.is_current(folder.persistent_id, generation, request) &&
            this.notifications.should_notify_new_messages(folder);
    }

    private string email_notification_id(EmailIdentifier id) {
        return "%s-%s".printf(ARRIVED_ID, id.to_variant().print(false));
    }

    private string folder_notification_id(Folder folder) {
        return "%s-%s".printf(ARRIVED_ID, folder.persistent_id);
    }

    private bool has_multiple_accounts() {
        var accounts = new Gee.HashSet<string>();
        foreach (Folder folder in this.folder_store.get_folders()) {
            if (folder.account != null) {
                accounts.add(folder.account.display_name);
            }
        }
        return accounts.size > 1;
    }

    private string with_account(string title, Folder folder) {
        if (folder.account != null && has_multiple_accounts()) {
            return "[%s] %s".printf(folder.account.display_name, title);
        }
        return title;
    }

    private async bool notify_specific_message(Folder folder,
                                               Email email,
                                               int64 generation,
                                               GLib.Cancellable request
    ) throws GLib.Error {
        if (!delivery_current(folder, generation, request)) return false;
        string title = to_notitication_title(folder.account, 1);
        GLib.Icon? icon = null;
        GriabuntuMail.RFC822.MailboxAddress? originator = email.get_primary_originator();
        if (originator != null) {
            ContactStore contacts =
                yield this.notifications.get_contacts_for_folder(folder);
            if (!delivery_current(folder, generation, request)) return false;
            global::Application.Contact? contact = yield contacts.load(
                originator, request
            );
            if (!delivery_current(folder, generation, request)) return false;

            title = (
                contact.is_trusted
                ? contact.display_name
                : originator.to_short_display()
            );

            icon = contact.avatar;
        }

        string body = Util.Email.strip_subject_prefixes(email);

        Gdk.Texture texture;
        if (icon != null) {
            int size = avatar_size();
            var icon_stream = yield ((LoadableIcon) icon).load_async(size, request);
            if (!delivery_current(folder, generation, request)) return false;
            var pixbuf = yield new Gdk.Pixbuf.from_stream_at_scale_async(
                icon_stream, size, size, false, request
            );
            if (!delivery_current(folder, generation, request)) return false;
            texture = round_texture(Gdk.Texture.for_pixbuf(pixbuf));
        } else {
            texture = generate_fallback_avatar(title);
        }

        return issue_arrived_notification(
            email_notification_id(email.identifier),
            title, body, texture, folder, email.identifier, generation, request
        );
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
        Gdk.RGBA bg = mix(hue, theme_color("view_bg_color", "#ffffff"), 0.32);
        Gdk.RGBA text = mix(hue, theme_color("window_fg_color", "#000000"), 0.58);

        var surface = new Cairo.ImageSurface(Cairo.Format.ARGB32, size, size);
        var cr = new Cairo.Context(surface);

        cr.arc(size / 2.0, size / 2.0, size / 2.0, 0, 2 * Math.PI);
        cr.set_source_rgb(bg.red, bg.green, bg.blue);
        cr.fill();

        // Ring, so the muted hues stay visible against the notification
        double ring = size / 48.0;
        cr.arc(size / 2.0, size / 2.0, (size - ring) / 2.0, 0, 2 * Math.PI);
        cr.set_source_rgba(text.red, text.green, text.blue, 0.45);
        cr.set_line_width(ring);
        cr.stroke();

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

    private void notify_general(Folder folder, int total, int added,
                                int64 generation, GLib.Cancellable request) {
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

        issue_arrived_notification(
            folder_notification_id(folder),
            title, body, icon, folder, null, generation, request
        );
    }

    private bool issue_arrived_notification(string notification_id,
                                            string summary,
                                            string body,
                                            GLib.Icon icon,
                                            Folder folder,
                                            EmailIdentifier? id,
                                            int64 generation,
                                            GLib.Cancellable request) {
        if (!delivery_current(folder, generation, request) || this.journal == null) {
            return false;
        }
        try {
            this.journal.record(notification_id);
        } catch (GLib.Error error) {
            warning("Could not record mail notification for recovery");
            return false;
        }
        this.arrived.set(folder.persistent_id, notification_id);

        string? action = null;
        GLib.Variant? target_param = null;
        if (id == null) {
            action = Action.Application.SHOW_FOLDER;
            target_param = folder.to_variant();
        } else {
            action = Action.Application.SHOW_EMAIL;
            target_param = id.to_variant();
        }

        issue_notification(
            notification_id,
            with_account(summary, folder),
            body,
            icon,
            Action.Application.prefix(action),
            target_param,
            id == null ? null : global::Application.NotificationActions.target(
                id.to_variant(), folder.to_variant()
            )
        );
        return true;
    }

    private GLib.Notification issue_notification(string id,
                                                 string summary,
                                                 string body,
                                                 GLib.Icon icon,
                                                 string? action,
                                                 GLib.Variant? action_target,
                                                 GLib.Variant? mail_target = null) {
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

            if (mail_target != null) {
                global::Application.NotificationActions.add_buttons(notification, mail_target);
            }
            this.client_application.send_notification(id, notification);
            return notification;
        }
    }

    private async void handle_new_messages(Folder folder,
                                           int total,
                                           Gee.Collection<EmailIdentifier> added,
                                           int64 generation,
                                           GLib.Cancellable request) {
        if (delivery_current(folder, generation, request)) {
            // notify about each message if there are only a few and
            // they can be loaded, otherwise notify generally
            bool notified = false;
            if (added.size <= MAX_INDIVIDUAL) {
                try {
                    foreach (Email message in
                             yield this.email_store.get_email(added, request)) {
                        if (!delivery_current(folder, generation, request)) return;
                        if (yield notify_specific_message(folder, message, generation, request)) {
                            notified = true;
                        }
                    }
                    if (!notified) {
                        warning("Could not load email for notification");
                    }
                } catch (GLib.Error error) {
                    if (!delivery_current(folder, generation, request)) return;
                    warning("Error loading email for notification: %s", error.message);
                }
            }

            if (!notified) {
                notify_general(folder, total, added.size, generation, request);
            }
        }
    }

    private void check_folders(Gee.Collection<Folder> folders) {
        foreach (Folder folder in folders) {
            if (folder.used_as in MONITORED_TYPES) {
                this.notifications.start_monitoring_folder(folder);
            } else {
                this.notifications.stop_monitoring_folder(folder);
                retire_folder(folder);
            }
        }
    }

    private void on_folders_unavailable(Gee.Collection<Folder> folders) {
        foreach (Folder folder in folders) {
            this.notifications.stop_monitoring_folder(folder);
            retire_folder(folder);
        }
    }

    private void retire_folder(Folder folder) {
        string key = folder.persistent_id;
        this.delivery.invalidate(key);
        foreach (string id in this.arrived.get(key)) withdraw_arrived(id);
        this.arrived.remove_all(key);
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
        if (this.cancellable != null && !this.cancellable.is_cancelled()) {
            this.handle_new_messages.begin(folder, total, added,
                this.delivery.capture(folder.persistent_id), this.cancellable);
        }
    }

    private void on_email_seen(Folder folder,
                               Gee.Collection<EmailIdentifier> seen) {
        this.delivery.invalidate(folder.persistent_id);
        string grouped = folder_notification_id(folder);
        withdraw_arrived(grouped);
        this.arrived.remove(folder.persistent_id, grouped);
        foreach (EmailIdentifier id in seen) {
            string notification_id = email_notification_id(id);
            withdraw_arrived(notification_id);
            this.arrived.remove(folder.persistent_id, notification_id);
        }
    }

    private void on_new_messages_retired(Folder folder, int total) {
        // This signal provides no retired IDs. All existing folder popups may
        // now be stale, including a group popup whose count has decreased.
        retire_folder(folder);
    }

}
