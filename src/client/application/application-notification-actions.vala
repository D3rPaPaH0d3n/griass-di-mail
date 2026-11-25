/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md. */
/*
 * Private downstream notification actions, added 2026-10-26.
 * Licensed under GPL-3.0-only. See COPYING.
 */

/** Shared, mail-specific notification target and stale-source checks. */
public class Application.NotificationActions : GLib.Object {
    public const string TARGET_TYPE = "((sv)(sv))";

    public enum Kind { REPLY, ARCHIVE, TRASH }

    public static GLib.Variant target(GLib.Variant email, GLib.Variant folder) {
        return new GLib.Variant.tuple({email, folder});
    }

    public static bool parse(GLib.Variant? value,
                             out GLib.Variant? email,
                             out GLib.Variant? folder) {
        email = null;
        folder = null;
        if (value == null || value.get_type_string() != TARGET_TYPE) return false;
        var message = value.get_child_value(0);
        var location = value.get_child_value(1);
        string account = message.get_child_value(0).get_string();
        if (account == "" || account != location.get_child_value(0).get_string())
            return false;
        // Notifications refer only to stored IMAP mail, never an outbox item.
        var id = message.get_child_value(1).get_variant();
        if (id.get_type_string() != "(y(xx))" ||
            id.get_child_value(0).get_byte() != 'i') return false;
        var numbers = id.get_child_value(1);
        int64 uid = numbers.get_child_value(1).get_int64();
        if (numbers.get_child_value(0).get_int64() <= 0 ||
            uid < -1 || uid == 0 || uid > uint32.MAX) return false;
        var path = location.get_child_value(1).get_variant();
        if (path.get_type_string() != "(sas)" ||
            path.get_child_value(0).get_string() == "" ||
            path.get_child_value(1).n_children() == 0) return false;
        foreach (string step in path.get_child_value(1).get_strv()) {
            if (step == "") return false;
        }
        email = message;
        folder = location;
        return true;
    }

    public static void add_buttons(GLib.Notification notification,
                                   GLib.Variant value) {
        GLib.Variant? email, folder;
        if (!parse(value, out email, out folder)) return;
        notification.add_button_with_target_value(
            _("Reply"), Action.Application.prefix(Action.Application.NOTIFICATION_REPLY), value
        );
        notification.add_button_with_target_value(
            _("Archive Message"), Action.Application.prefix(Action.Application.NOTIFICATION_ARCHIVE), value
        );
        notification.add_button_with_target_value(
            _("Delete Message"), Action.Application.prefix(Action.Application.NOTIFICATION_TRASH), value
        );
    }

    /** Use only the existing exact-message move command, never archive fallbacks. */
    public static async void move_message(GriabuntuMail.Folder source,
                                          GriabuntuMail.Folder destination,
                                          GriabuntuMail.EmailIdentifier id,
                                          CommandStack commands,
                                          GLib.Cancellable? cancellable)
        throws GLib.Error {
        var movable = source as GriabuntuMail.FolderSupport.Move;
        if (movable == null || source.account == null ||
            source.account != destination.account || source.path.equal_to(destination.path) ||
            !(destination.used_as == ARCHIVE || destination.used_as == ALL_MAIL || destination.used_as == TRASH))
            throw new GriabuntuMail.EngineError.BAD_PARAMETERS("Unsafe notification destination");
        yield check_source(source, id, cancellable);
        var messages = new Gee.ArrayList<GriabuntuMail.EmailIdentifier>();
        messages.add(id);
        yield commands.execute(new MoveEmailCommand(
            movable, destination, new Gee.ArrayList<GriabuntuMail.App.Conversation>(), messages
        ), cancellable);
    }

    /** Never reinterpret a stale click against a different folder or message. */
    public static async void check_source(GriabuntuMail.Folder source,
                                          GriabuntuMail.EmailIdentifier id,
                                          GLib.Cancellable? cancellable)
        throws GLib.Error {
        if (source.used_as != INBOX && source.used_as != NONE)
            throw new GriabuntuMail.EngineError.BAD_PARAMETERS("Unsafe notification source");
        if (cancellable != null) cancellable.set_error_if_cancelled();
        bool opened = false;
        try {
            yield source.open_async(GriabuntuMail.Folder.OpenFlags.NO_DELAY, cancellable);
            opened = true;
            var found = yield source.contains_identifiers(
                GriabuntuMail.Collection.single(id), cancellable
            );
            if (cancellable != null) cancellable.set_error_if_cancelled();
            if (found.size != 1 || !GriabuntuMail.Collection.first(found).equal_to(id))
                throw new GriabuntuMail.EngineError.NOT_FOUND("Notification mail is no longer in its source");
        } finally {
            if (opened) {
                try { yield source.close_async(null); }
                catch (GLib.Error error) { debug("Notification source close: %s", error.message); }
            }
        }
    }
}
