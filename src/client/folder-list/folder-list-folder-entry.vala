/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

// A folder of any type in the folder list.
public class FolderList.FolderEntry :
    FolderList.AbstractFolderEntry,
    Sidebar.InternalDropTargetEntry,
    Sidebar.EmphasizableEntry,
    Sidebar.RenameableEntry,
    Sidebar.DestroyableEntry {


    private Application.FolderContext context;
    private bool has_new;


    public FolderEntry(Application.FolderContext context) {
        base(context.folder);
        this.context = context;
        this.context.notify.connect(on_context_changed);
        this.has_new = false;
        this.folder.properties.notify[Convey.FolderProperties.PROP_NAME_EMAIL_TOTAL].connect(on_counts_changed);
        this.folder.properties.notify[Convey.FolderProperties.PROP_NAME_EMAIL_UNREAD].connect(on_counts_changed);
    }

    ~FolderEntry() {
        this.context.notify.disconnect(on_context_changed);
        this.folder.properties.notify[Convey.FolderProperties.PROP_NAME_EMAIL_TOTAL].disconnect(on_counts_changed);
        this.folder.properties.notify[Convey.FolderProperties.PROP_NAME_EMAIL_UNREAD].disconnect(on_counts_changed);
    }

    public override string get_sidebar_name() {
        return this.context.display_name;
    }

    public override string? get_sidebar_tooltip() {
        // Translators: Label displaying total number of email
        // messages in a folder. String substitution is the actual
        // number.
        string total_msg = ngettext(
            "%d message", "%d messages", folder.properties.email_total
        ).printf(folder.properties.email_total);

        if (folder.properties.email_unread == 0)
            return total_msg;

        // Translators: Label displaying number of unread email
        // messages in a folder. String substitution is the actual
        // number.
        string unread_msg = ngettext(
            "%d unread", "%d unread", folder.properties.email_unread
        ).printf(folder.properties.email_unread);

        // Translators: This string represents the divider between two
        // messages: "n messages" and "n unread", shown in the folder
        // list as a tooltip.  Please use your languages conventions
        // for combining the two, i.e. a comma (",") for English; "6
        // messages, 3 unread"
        return _("%s, %s").printf(total_msg, unread_msg);
    }

    public override string? get_sidebar_icon() {
        return this.context.icon_name;
    }

    public override string to_string() {
        return "FolderEntry: " + get_sidebar_name();
    }

    public bool is_emphasized() {
        return has_new;
    }

    public void set_has_new(bool has_new) {
        if (this.has_new == has_new)
            return;

        this.has_new = has_new;
        entry_changed();
    }

    /** Only plain user folders can be renamed or deleted. */
    public bool is_user_renameable() {
        return this.folder.used_as == NONE;
    }

    public void rename(string new_name) {
        var name = new_name.strip();
        if (this.tree != null && name != "" && name != get_sidebar_name()) {
            this.tree.folder_rename(this.folder, name);
        }
    }

    public void destroy_source() {
        if (this.tree != null && is_user_renameable()) {
            this.tree.folder_delete(this.folder);
        }
    }

    public bool internal_drop_received(Sidebar.Tree parent,
                                       Gdk.DragAction action) {
        var folders = parent as FolderList.Tree;
        if (folders == null)
            return false;

        if (!folders.accepts_drop(this.folder))
            return false;

        // Dragging always moves; copying is offered in the folder
        // picker instead, where it can be chosen deliberately.
        folders.move_conversation(this.folder);
        return true;
    }

    public override int get_count() {
        switch (this.context.displayed_count) {
        case TOTAL:
            return folder.properties.email_total;

        case UNREAD:
            return folder.properties.email_unread;

        default:
            return 0;
        }
    }

    private void on_counts_changed() {
        entry_changed();
    }

    private void on_context_changed() {
        entry_changed();
    }

}
