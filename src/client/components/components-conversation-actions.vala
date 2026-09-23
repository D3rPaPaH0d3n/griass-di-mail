/*
 * Copyright © 2017 Software Freedom Conservancy Inc.
 * Copyright © 2021 Michael Gratton <mike@vee.net>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

/**
 * A container of conversation-related actions.
 */
[GtkTemplate (ui = "/net/donnybeelo/Convey/components-conversation-actions.ui")]
public class Components.ConversationActions : Gtk.Box {

    public bool show_conversation_actions {
        get { return this.action_buttons.visible; }
        set {
            if (this.action_buttons.visible == value)
                return;
            this.action_buttons.visible = value;
            notify_property("show-conversation-actions");
        }
    }

    public bool show_response_actions {
        get { return this.response_buttons.visible; }
        set {
            if (this.response_buttons.visible == value)
                return;
            this.response_buttons.visible = value;
            notify_property("show-conversation-actions");
        }
    }

    public bool pack_justified { get; construct; }

    public bool compact { get; set; default = false; }

    public FolderPopover copy_popover {
        get {
            unowned var popover = this.copy_message_button.popover as FolderPopover;
            return popover;
        }
    }

    public FolderPopover move_popover {
        get {
            unowned var popover = this.move_message_button.popover as FolderPopover;
            return popover;
        }
    }

    public int selected_conversations { get; set; }

    /** The folder the selected conversations are currently in. */
    public Convey.Folder? source_folder { get; set; }

    private Convey.Account _account;
    public Convey.Account account {
        get {
            return this._account;
        }
        set {
            this._account = value;
            this.update_conversation_buttons();
        }
    }

    [GtkChild] private unowned Gtk.Box response_buttons { get; }

    [GtkChild] private unowned Gtk.MenuButton mark_message_button { get; }
    [GtkChild] private unowned Gtk.MenuButton copy_message_button { get;  }
    [GtkChild] private unowned Gtk.MenuButton move_message_button { get;  }

    [GtkChild] private unowned Gtk.Box action_buttons;
    [GtkChild] private unowned Gtk.Button archive_button;
    [GtkChild] private unowned Gtk.Button trash_delete_button;

    private bool show_trash_button = true;
    private FolderPopover compact_copy_popover = new FolderPopover(false);

    static construct {
        set_css_name("components-conversation-actions");
    }

    // GObject style constuction to support loading via GTK Builder files
    construct {
        // Assemble the mark menus
        Gtk.Builder menu_builder = new Gtk.Builder.from_resource(
            "/net/donnybeelo/Convey/components-menu-conversation.ui"
        );
        GLib.MenuModel mark_menu = (MenuModel) menu_builder.get_object(
            "mark_message_menu"
        );

        this.notify["selected-conversations"].connect(() => update_conversation_buttons());
        this.notify["service-provider"].connect(() => update_conversation_buttons());
        this.mark_message_button.menu_model = mark_menu;
        this.compact_copy_popover.set_parent(this.action_buttons);
        this.compact_copy_popover.copy_conversation.connect(
            (folder) => this.copy_popover.copy_conversation(folder)
        );
        this.bind_property(
            "compact", this.copy_message_button, "visible",
            SYNC_CREATE | INVERT_BOOLEAN
        );

        this.mark_message_button.activate.connect((button) => {
            if (button.active)
                mark_message_button_toggled();
        });

        if (this.pack_justified) {
            this.action_buttons.hexpand = true;
            this.action_buttons.halign = END;
        }
    }

    public void init(Application.Configuration config) {
        this.copy_message_button.popover = new FolderPopover(false);
        this.move_message_button.popover = new FolderPopover(true);
        this.bind_property(
            "account", this.copy_message_button.popover,
            "account", BindingFlags.SYNC_CREATE
        );
        this.bind_property(
            "account", this.move_message_button.popover,
            "account", BindingFlags.SYNC_CREATE
        );
        this.bind_property(
            "source-folder", this.copy_message_button.popover,
            "source", BindingFlags.SYNC_CREATE
        );
        this.bind_property(
            "source-folder", this.move_message_button.popover,
            "source", BindingFlags.SYNC_CREATE
        );
        this.bind_property(
            "account", this.compact_copy_popover,
            "account", BindingFlags.SYNC_CREATE
        );
        this.bind_property(
            "source-folder", this.compact_copy_popover,
            "source", BindingFlags.SYNC_CREATE
        );
    }

    public override void dispose() {
        this.compact_copy_popover.unparent();
        base.dispose();
    }

    public void set_copy_sensitive(bool is_sensitive) {
        this.copy_message_button.sensitive = is_sensitive;
        this.move_message_button.sensitive = is_sensitive;
    }

    public void set_mark_sensitive(bool is_sensitive) {
        this.mark_message_button.sensitive = is_sensitive;
    }

    public void show_copy_menu() {
        if (this.compact) {
            this.compact_copy_popover.popup();
        } else {
            this.copy_message_button.active = true;
        }
    }

    public void set_mark_inverted() {
        this.mark_message_button.icon_name = "pan-up-symbolic";
    }

    public void update_trash_button(bool show_trash) {
        this.show_trash_button = show_trash;
        update_conversation_buttons();
    }

    /** Fired when the user toggles the mark message button. */
    public signal void mark_message_button_toggled();

    /** Updates tooltip text depending on number of conversations selected. */
    private void update_conversation_buttons() {
        this.mark_message_button.tooltip_text = ngettext(
            "Mark conversation",
            "Mark conversations",
            this.selected_conversations
            );

        this.archive_button.tooltip_text = ngettext(
            "Archive conversation",
            "Archive conversations",
            this.selected_conversations
            );

        this.copy_message_button.tooltip_text = ngettext(
            "Copy conversation to a folder",
            "Copy conversations to a folder",
            this.selected_conversations
            );

        this.move_message_button.tooltip_text = ngettext(
            "Move conversation to a folder",
            "Move conversations to a folder",
            this.selected_conversations
            );

        if (this.show_trash_button) {
            this.trash_delete_button.action_name = Action.Window.prefix(
                Application.MainWindow.ACTION_TRASH_CONVERSATION
                );
            this.trash_delete_button.icon_name = "user-trash-symbolic";
            this.trash_delete_button.tooltip_text = ngettext(
                "Move conversation to Trash",
                "Move conversations to Trash",
                this.selected_conversations
                );
        } else {
            this.trash_delete_button.action_name = Action.Window.prefix(
                Application.MainWindow.ACTION_DELETE_CONVERSATION
                );
            this.trash_delete_button.icon_name = "edit-delete-symbolic";
            this.trash_delete_button.tooltip_text = ngettext(
                "Delete conversation",
                "Delete conversations",
                this.selected_conversations
                );
        }
    }
}
