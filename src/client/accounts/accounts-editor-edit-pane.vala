/* Downstream modification: 2026-10-28 — Griaß di Mail display name; compatibility IDs retained. */
/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2018-2019 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * An account editor pane for editing a specific account's preferences.
 */
[GtkTemplate (ui = "/io/github/d3rpapah0d3n/GriabuntuMail/accounts_editor_edit_pane.ui")]
internal class Accounts.EditorEditPane : EditorPane, AccountPane, CommandPane {


    /** {@inheritDoc} */
    internal GriabuntuMail.AccountInformation account { get ; protected set; }

    /** {@inheritDoc} */
    internal Application.CommandStack commands {
        get; protected set; default = new Application.CommandStack();
    }

    /** {@inheritDoc} */
    internal override bool is_operation_running { get; protected set; default = false; }

    /** {@inheritDoc} */
    internal override Cancellable? op_cancellable {
        get; protected set; default = null;
    }

    /** {@inheritDoc} */
    protected override weak Accounts.Editor editor { get; set; }


    [GtkChild] private unowned Adw.EntryRow display_name_row;

    [GtkChild] private unowned Gtk.ListBox senders_list;

    [GtkChild] private unowned Adw.PreferencesGroup signature_bin;

    private Composer.Editor signature_editor;
    private bool signature_changed = false;

    [GtkChild] private unowned Adw.ComboRow email_prefetch_row;
    [GtkChild] private unowned Adw.SwitchRow archive_instead_of_trash_row;

    [GtkChild] private unowned Gtk.Button undo_button;

    [GtkChild] private unowned Gtk.Button remove_button;


    public EditorEditPane(Editor editor, GriabuntuMail.AccountInformation account) {
        this.editor = editor;
        this.account = account;

        update_display_name();

        foreach (GriabuntuMail.RFC822.MailboxAddress sender in
                 account.sender_mailboxes) {
            this.senders_list.append(new_mailbox_row(sender));
        }

        this.signature_editor = new_signature_editor(account.signature);
        this.signature_editor.body.document_modified.connect(() => {
                this.signature_changed = true;
            });
        var focus_controller = new Gtk.EventControllerFocus();
        focus_controller.leave.connect(() => {
            // This event will also be fired if the top-level
            // window loses focus, e.g. if the user alt-tabs away,
            // so don't execute the command if the signature web
            // view no longer the focus widget
            if (!this.signature_editor.body.is_focus() &&
                this.signature_changed) {
                this.commands.execute.begin(
                    new SignatureChangedCommand(
                        this.signature_editor.body, account
                    ),
                    this.op_cancellable
                );
            }
        });
        this.signature_editor.body.add_controller(focus_controller);

        this.signature_bin.add(this.signature_editor);

        this.remove_button.set_visible(
            !this.editor.accounts.is_goa_account(account)
        );

        update_prefetch_period();
        this.email_prefetch_row.notify["selected"].connect(
            on_prefetch_period_changed
        );

        this.archive_instead_of_trash_row.active =
            this.account.archive_instead_of_trash;
        this.archive_instead_of_trash_row.notify["active"].connect(
            on_archive_instead_of_trash_changed
        );

        // Commit the account name when the row loses focus, rather
        // than on every keystroke, so the undo stack gets one entry
        // per edit.
        var name_focus = new Gtk.EventControllerFocus();
        name_focus.leave.connect(commit_display_name);
        this.display_name_row.add_controller(name_focus);

        connect_account_signals();
        connect_command_signals();
    }

    ~EditorEditPane() {
        disconnect_account_signals();
        disconnect_command_signals();
    }

    /** {@inheritDoc} */
    protected override void account_changed() {
        update_prefetch_period();
        if (this.archive_instead_of_trash_row.active !=
            this.account.archive_instead_of_trash) {
            this.archive_instead_of_trash_row.active =
                this.account.archive_instead_of_trash;
        }
        // Don't yank the text out from under someone who is typing
        if (!this.display_name_row.has_focus) {
            update_display_name();
        }
    }

    private void update_display_name() {
        // Show the fallback address as a placeholder rather than as
        // text, so an unset label doesn't look like a user-set one.
        this.display_name_row.text = this.account.label;
        Gtk.Editable? editable = this.display_name_row.get_delegate();
        if (editable != null) {
            ((Gtk.Text) editable).placeholder_text =
                this.account.primary_mailbox.address;
        }
    }

    private void commit_display_name() {
        string value = this.display_name_row.text.strip();
        if (value == this.account.label) {
            return;
        }
        this.commands.execute.begin(
            new Application.PropertyCommand<string?>(
                this.account,
                "label",
                value,
                // Translators: Tooltip used to undo changing the name
                // of an account. The string substitution is the old
                // name of the account.
                _("Change account name back to “%s”").printf(
                    this.account.display_name
                )
            ),
            this.op_cancellable
        );
    }

    private void update_prefetch_period() {
        var model = (Adw.EnumListModel) this.email_prefetch_row.model;
        uint position = model.find_position(
            this.account.prefetch_period_days
        );
        if (position != Gtk.INVALID_LIST_POSITION &&
            this.email_prefetch_row.selected != position) {
            this.email_prefetch_row.selected = position;
        }
    }

    private void on_prefetch_period_changed() {
        var item = this.email_prefetch_row.selected_item as Adw.EnumListItem;
        if (item == null || item.value == this.account.prefetch_period_days) {
            return;
        }
        this.commands.execute.begin(
            new Application.PropertyCommand<int>(
                this.account,
                "prefetch-period-days",
                item.value,
                // Translators: Tooltip for undoing a change to the
                // length of time that past email should be downloaded
                // for an account. The string substitution is the
                // duration, e.g. "1 month back".
                _("Change download period back to: %s").printf(
                    ((PrefetchPeriod) this.account.prefetch_period_days)
                        .to_string()
                )
            ),
            this.op_cancellable
        );
    }

    private void on_archive_instead_of_trash_changed() {
        bool active = this.archive_instead_of_trash_row.active;
        if (active == this.account.archive_instead_of_trash) {
            return;
        }
        this.commands.execute.begin(
            new Application.PropertyCommand<bool>(
                this.account,
                "archive-instead-of-trash",
                active,
                active
                    ? _("Undo archive instead of moving to Trash")
                    : _("Undo move to Trash instead of archiving")
            ),
            this.op_cancellable
        );
    }

    internal string? get_default_name() {
        string? name = this.account.primary_mailbox.name;

        if (GriabuntuMail.String.is_empty_or_whitespace(name)) {
            name = this.editor.accounts.get_account_name();
        }

        return name;
    }

    internal Composer.Editor new_signature_editor(string signature) {
        var signature_editor = new Composer.Editor(
            this.editor.application.config,
            this.editor.application.controller.get_web_cache_dir()
        );
        signature_editor.load_signature(signature);
        return signature_editor;
    }

    internal MailboxRow new_mailbox_row(GriabuntuMail.RFC822.MailboxAddress sender) {
        MailboxRow row = new MailboxRow(this.account, sender, this);
        row.move_to.connect(on_sender_row_moved);
        row.dropped.connect(on_sender_row_dropped);
        return row;
    }

    /** {@inheritDoc} */
    protected void command_executed() {
        this.editor.update_command_actions();

        Application.Command next_undo = this.commands.peek_undo();
        this.undo_button.set_tooltip_text(
            (next_undo != null && next_undo.undo_label != null)
            ? next_undo.undo_label : _("Undo")
        );

        // Ensure the account is notified that is has changed. This
        // might not be 100% correct, but it's close enough.
        this.account.changed();
    }

    private void on_sender_row_moved(MailboxRow source, int new_position) {
        this.commands.execute.begin(
            new ReorderMailboxCommand(
                source,
                new_position,
                this.account,
                this.senders_list
            ),
            this.op_cancellable
        );
    }

    private void on_sender_row_dropped(MailboxRow source, MailboxRow target) {
        this.commands.execute.begin(
            new ReorderMailboxCommand(
                source,
                target.get_index(),
                this.account,
                this.senders_list
            ),
            this.op_cancellable
        );
    }

    [GtkCallback]
    private void on_server_settings_clicked() {
        this.editor.push_pane(new EditorServersPane(this.editor, this.account));
    }

    [GtkCallback]
    private void on_remove_account_clicked() {
        if (!this.editor.accounts.is_goa_account(account)) {
            var dialog = new Adw.AlertDialog(
                _("Remove Account: %s").printf(account.primary_mailbox.address),
                _("This will remove it from Griaß di Mail and delete locally cached email data from your computer. Nothing will be deleted from your service provider.")
            );
            dialog.add_css_class("warning");

            dialog.add_response("cancel", _("_Cancel"));
            dialog.close_response = "cancel";
            dialog.add_response("remove", _("_Remove Account"));
            dialog.set_response_appearance("remove", Adw.ResponseAppearance.DESTRUCTIVE);

            dialog.choose.begin(this, null, (obj, res) => {
                string response = dialog.choose.end(res);
                if (response == "remove")
                    this.editor.remove_account(this.account);
            });
        }
    }

    [GtkCallback]
    private void on_add_mailbox_clicked(Gtk.Button add_button) {
        var dialog = new MailboxEditorDialog.for_new(
            get_default_name(), new_signature_editor("")
        );
        dialog.apply.connect((dialog, mailbox, signature) => {
            this.commands.execute.begin(
                new AppendMailboxCommand(
                    this.senders_list,
                    new_mailbox_row(mailbox),
                    signature
                ),
                this.op_cancellable
            );
            dialog.close();
        });

        dialog.present(this);
    }

    [GtkCallback]
    private static string period_to_string(Adw.EnumListItem item,
                                           Accounts.PrefetchPeriod period) {
        return period.to_string();
    }
}


/**
 * An enum to describe the possible values for the "Download Mail" option
 */
public enum Accounts.PrefetchPeriod {

    2_WEEKS = 14,
    1_MONTH = 30,
    3_MONTHS = 90,
    6_MONTHS = 180,
    1_YEAR = 365,
    2_YEARS = 720,
    4_YEARS = 1461,
    EVERYTHING = -1;

    public unowned string to_string() {
        switch (this) {
        case 2_WEEKS:
            return _("2 weeks back");
        case 1_MONTH:
            return _("1 month back");
        case 3_MONTHS:
            return _("3 months back");
        case 6_MONTHS:
            return _("6 months back");
        case 1_YEAR:
            return _("1 year back");
        case 2_YEARS:
            return _("2 years back");
        case 4_YEARS:
            return _("4 years back");
        case EVERYTHING:
            return _("Everything");
        }

        return_val_if_reached("");
    }
}

private class Accounts.MailboxRow : Adw.ActionRow {

    public GriabuntuMail.AccountInformation account { get; construct set; }

    public GriabuntuMail.RFC822.MailboxAddress mailbox { get; construct set; }

    public unowned Accounts.EditorEditPane pane { get; construct set; }

    private Gtk.Image drag_handle;
    private bool drag_picked_up = false;


    public signal void move_to(int new_position);
    public signal void dropped(MailboxRow target);


    public MailboxRow(GriabuntuMail.AccountInformation account,
                      GriabuntuMail.RFC822.MailboxAddress mailbox,
                      Accounts.EditorEditPane pane) {
        Object(
            account: account,
            mailbox: mailbox,
            pane: pane,
            activatable: true
        );

        enable_drag();
        update();

        // The edit dialog and undo both swap the mailbox out from under us
        this.notify["mailbox"].connect(() => update());
    }

    /** Adds a drag handle to the row and enables drag signals. */
    private void enable_drag() {
        this.drag_handle = new Gtk.Image.from_icon_name(
            "list-drag-handle-symbolic"
        );
        this.drag_handle.valign = Gtk.Align.CENTER;
        // Translators: Tooltip for dragging list items
        this.drag_handle.set_tooltip_text(_("Drag to move this item"));
        this.drag_handle.add_css_class("griabuntu-mail-drag-handle");
        add_suffix(this.drag_handle);

        var drag_source = new Gtk.DragSource();
        drag_source.actions = Gdk.DragAction.MOVE;
        drag_source.prepare.connect(on_drag_prepare);
        drag_source.drag_begin.connect(on_drag_begin);
        drag_source.drag_end.connect(on_drag_end);
        this.drag_handle.add_controller(drag_source);

        // Accept drops anywhere on the row, not just on the handle,
        // so there's a target big enough to actually hit.
        var drop_target = new Gtk.DropTarget(
            typeof(int), Gdk.DragAction.MOVE
        );
        drop_target.enter.connect(on_drop_enter);
        drop_target.leave.connect(on_drop_leave);
        drop_target.drop.connect(on_drop);
        add_controller(drop_target);

        add_css_class("griabuntu-mail-draggable");

        var key_controller = new Gtk.EventControllerKey();
        key_controller.key_pressed.connect(on_key_pressed);
        add_controller(key_controller);
    }

    private Gdk.ContentProvider on_drag_prepare(Gtk.DragSource source,
                                                double x,
                                                double y) {
        var val = GLib.Value(typeof(int));
        val.set_int(get_index());
        return new Gdk.ContentProvider.for_value(val);
    }

    private void on_drag_begin(Gtk.DragSource source, Gdk.Drag drag) {
        var paintable = new Gtk.WidgetPaintable(this);
        source.set_icon(paintable, 0, 0);
        add_css_class("griabuntu-mail-drag-source");
        this.drag_picked_up = true;
    }

    private void on_drag_end(Gtk.DragSource source,
                             Gdk.Drag drag,
                             bool delete_data) {
        remove_css_class("griabuntu-mail-drag-source");
        this.drag_picked_up = false;
    }

    private Gdk.DragAction on_drop_enter(Gtk.DropTarget target,
                                         double x,
                                         double y) {
        // Don't highlight the row that was picked up
        if (!this.drag_picked_up) {
            var parent = get_parent() as Gtk.ListBox;
            if (parent != null) {
                parent.drag_highlight_row(this);
            }
        }
        return Gdk.DragAction.MOVE;
    }

    private void on_drop_leave(Gtk.DropTarget target) {
        if (!this.drag_picked_up) {
            var parent = get_parent() as Gtk.ListBox;
            if (parent != null) {
                parent.drag_unhighlight_row();
            }
        }
    }

    private bool on_drop(Gtk.DropTarget target,
                         GLib.Value val,
                         double x,
                         double y) {
        if (!val.holds(typeof(int))) {
            return false;
        }

        var parent = get_parent() as Gtk.ListBox;
        if (parent == null) {
            return false;
        }

        var source = parent.get_row_at_index(val.get_int()) as MailboxRow;
        if (source == null || source == this) {
            return false;
        }

        source.dropped(this);
        return true;
    }

    // Ctrl+Up/Down moves the row, for people who can't or won't drag.
    private bool on_key_pressed(Gtk.EventControllerKey controller,
                                uint keyval,
                                uint keycode,
                                Gdk.ModifierType state) {
        if (state != Gdk.ModifierType.CONTROL_MASK) {
            return Gdk.EVENT_PROPAGATE;
        }

        var parent = get_parent() as Gtk.ListBox;
        if (parent == null) {
            return Gdk.EVENT_PROPAGATE;
        }

        int index = get_index();
        if (keyval == Gdk.Key.Up && index > 0) {
            move_to(index - 1);
            return Gdk.EVENT_STOP;
        }
        if (keyval == Gdk.Key.Down &&
            parent.get_row_at_index(index + 1) != null) {
            move_to(index + 1);
            return Gdk.EVENT_STOP;
        }

        return Gdk.EVENT_PROPAGATE;
    }

    public override void activate() {
        var dialog = new MailboxEditorDialog.for_existing(
            this.mailbox,
            this.account.has_sender_aliases,
            this.pane.new_signature_editor(
                this.account.get_sender_signature(this.mailbox)
            )
        );

        dialog.apply.connect((dialog, mailbox, signature) => {
            this.pane.commands.execute.begin(
                new UpdateMailboxCommand(this, mailbox, signature),
                this.pane.op_cancellable
            );
            dialog.close();
        });

        dialog.remove.connect((dialog) => {
            this.pane.commands.execute.begin(
                new RemoveMailboxCommand(this),
                this.pane.op_cancellable
            );
            dialog.close();
        });

        dialog.present(this);
    }

    private void update() {
        this.title = mailbox.address.strip();

        string? name = this.mailbox.name;
        if (GriabuntuMail.String.is_empty_or_whitespace(name)) {
            // Translators: Label used to indicate the user has
            // provided no display name for one of their sender
            // email addresses in their account settings.
            name = _("Name not set");
        }
        this.subtitle = name;
    }

}


internal class Accounts.AppendMailboxCommand : Application.Command {


    private Gtk.ListBox senders_list;
    private MailboxRow new_row = null;
    private string signature;

    private int mailbox_index;


    public AppendMailboxCommand(Gtk.ListBox senders_list,
                                MailboxRow new_row,
                                string signature) {
        this.senders_list = senders_list;
        this.new_row = new_row;
        this.signature = signature;

        this.mailbox_index = new_row.account.sender_mailboxes.size;

        // Translators: Label used as the undo tooltip after adding an
        // new sender email address to an account. The string
        // substitution is the email address added.
        this.undo_label = _("Remove “%s”").printf(new_row.mailbox.address);
    }

    public async override void execute(GLib.Cancellable? cancellable) {
        this.senders_list.insert(this.new_row, this.mailbox_index);
        this.new_row.account.append_sender(this.new_row.mailbox);
        this.new_row.account.set_sender_signature(
            this.new_row.mailbox, this.signature
        );
        this.new_row.account.changed();
    }

    public async override void undo(GLib.Cancellable? cancellable) {
        this.senders_list.remove(this.new_row);
        this.new_row.account.remove_sender(this.new_row.mailbox);
        this.new_row.account.set_sender_signature(this.new_row.mailbox, "");
        this.new_row.account.changed();
    }

}


internal class Accounts.UpdateMailboxCommand : Application.Command {


    private MailboxRow row;
    private GriabuntuMail.RFC822.MailboxAddress new_mailbox;
    private string new_signature;

    private GriabuntuMail.RFC822.MailboxAddress old_mailbox;
    private string old_signature;
    private int mailbox_index;


    public UpdateMailboxCommand(MailboxRow row,
                                GriabuntuMail.RFC822.MailboxAddress new_mailbox,
                                string new_signature) {
        this.row = row;
        this.new_mailbox = new_mailbox;
        this.new_signature = new_signature;

        this.old_mailbox = row.mailbox;
        this.old_signature = row.account.get_sender_signature(row.mailbox);
        this.mailbox_index =
            row.account.sender_mailboxes.index_of(this.old_mailbox);

        // Translators: Label used as the undo tooltip after editing a
        // sender address for an account. The string substitution is
        // the email address edited.
        this.undo_label = _("Undo changes to “%s”").printf(
            this.old_mailbox.address
        );
    }

    public async override void execute(GLib.Cancellable? cancellable) {
        this.row.mailbox = this.new_mailbox;
        this.row.account.replace_sender(this.mailbox_index, this.new_mailbox);
        this.row.account.set_sender_signature(this.old_mailbox, "");
        this.row.account.set_sender_signature(
            this.new_mailbox, this.new_signature
        );
        this.row.account.changed();
    }

    public async override void undo(GLib.Cancellable? cancellable) {
        this.row.mailbox = this.old_mailbox;
        this.row.account.replace_sender(this.mailbox_index, this.old_mailbox);
        this.row.account.set_sender_signature(this.new_mailbox, "");
        this.row.account.set_sender_signature(
            this.old_mailbox, this.old_signature
        );
        this.row.account.changed();
    }

}


internal class Accounts.ReorderMailboxCommand : Application.Command {


    private MailboxRow source;
    private int source_index;
    private int target_index;

    private GriabuntuMail.AccountInformation account;
    private Gtk.ListBox list;


    public ReorderMailboxCommand(MailboxRow source,
                                 int target_index,
                                 GriabuntuMail.AccountInformation account,
                                 Gtk.ListBox list) {
        this.source = source;
        this.source_index = source.get_index();
        this.target_index = target_index;

        this.account = account;
        this.list = list;
    }

    public async override void execute(GLib.Cancellable? cancellable)
        throws GLib.Error {
        move_source(this.target_index);
    }

    public async override void undo(GLib.Cancellable? cancellable)
        throws GLib.Error {
        move_source(this.source_index);
    }

    private void move_source(int destination) {
        this.account.remove_sender(this.source.mailbox);
        this.account.insert_sender(destination, this.source.mailbox);

        this.list.remove(this.source);
        this.list.insert(this.source, destination);

        this.source.grab_focus();
    }

}


internal class Accounts.RemoveMailboxCommand : Application.Command {


    private MailboxRow row;

    private GriabuntuMail.RFC822.MailboxAddress mailbox;
    private int mailbox_index;
    private Gtk.ListBox list;


    public RemoveMailboxCommand(MailboxRow row) {
        this.row = row;

        this.mailbox = row.mailbox;
        this.mailbox_index =
            row.account.sender_mailboxes.index_of(mailbox);
        this.list = (Gtk.ListBox) row.get_parent();

        // Translators: Label used as the undo tooltip after removing
        // a sender address from an account. The string substitution
        // is the email address edited.
        this.undo_label = _("Add “%s” back").printf(this.mailbox.address);
    }

    public async override void execute(GLib.Cancellable? cancellable) {
        this.list.remove(this.row);
        this.row.account.remove_sender(this.mailbox);
        this.row.account.changed();
    }

    public async override void undo(GLib.Cancellable? cancellable) {
        this.list.insert(this.row, this.mailbox_index);
        this.row.account.insert_sender(this.mailbox_index, this.mailbox);
        this.row.account.changed();
    }

}


internal class Accounts.SignatureChangedCommand : Application.Command {


    private Composer.WebView signature_view;
    private GriabuntuMail.AccountInformation account;

    private string old_value;
    private bool old_enabled;

    private string? new_value = null;
    private bool new_enabled = false;


    public SignatureChangedCommand(Composer.WebView signature_view,
                                   GriabuntuMail.AccountInformation account) {
        this.signature_view = signature_view;
        this.account = account;

        this.old_value = GriabuntuMail.HTML.smart_escape(account.signature);
        this.old_enabled = account.use_signature;

        // Translators: Label used as the undo tooltip after removing
        // a sender address from an account. The string substitution
        // is the email address edited.
        this.undo_label = _("Undo signature changes");
    }

    public async override void execute(GLib.Cancellable? cancellable)
        throws GLib.Error {
        this.new_value = yield this.signature_view.get_body_html();
        this.new_enabled = !GriabuntuMail.String.is_empty(this.new_value);
        update_account_signature(this.new_value, this.new_enabled);
    }

    public async override void undo(GLib.Cancellable? cancellable) {
        this.signature_view.load_signature(this.old_value);
        update_account_signature(this.old_value, this.old_enabled);
    }

    public async override void redo(GLib.Cancellable? cancellable) {
        this.signature_view.load_signature(this.new_value);
        update_account_signature(this.new_value, this.new_enabled);
    }

    private inline void update_account_signature(string sig, bool enabled) {
        this.account.signature = sig;
        this.account.use_signature = enabled;
        this.account.changed();
    }


}
