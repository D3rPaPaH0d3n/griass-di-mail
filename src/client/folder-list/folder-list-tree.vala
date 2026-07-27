/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

public class FolderList.Tree : Sidebar.Tree, Convey.BaseInterface {


    private const int INBOX_ORDINAL = -2; // First account branch is zero
    private const int SEARCH_ORDINAL = -1;


    public signal void folder_selected(Convey.Folder? folder);
    public signal void folder_activated(Convey.Folder? folder);
    public signal void copy_conversation(Convey.Folder folder);
    public signal void move_conversation(Convey.Folder folder);

    public Convey.Folder? selected { get ; private set; default = null; }

    private Gee.HashMap<Convey.Account, AccountBranch> account_branches
        = new Gee.HashMap<Convey.Account, AccountBranch>();
    private InboxesBranch inboxes_branch = new InboxesBranch();
    private SearchBranch? search_branch = null;


    public Tree() {
        base();
        base_ref();
        set_activate_on_single_click(true);
        entry_selected.connect(on_entry_selected);
        entry_activated.connect(on_entry_activated);

        this.visible = true;
    }

    ~Tree() {
        base_unref();
    }

    public override void measure(Gtk.Orientation orientation,
                                 int for_size,
                                 out int minimum,
                                 out int natural,
                                 out int minimum_baseline,
                                 out int natural_baseline) {
        minimum = natural = 0;
        if (orientation == Gtk.Orientation.HORIZONTAL) {
            minimum = 180;
            natural = 300;
        } else {
            // Height is whatever the list view needs; the sidebar
            // imposes no minimum of its own.
            Gtk.Widget? child = get_first_child();
            if (child != null) {
                child.measure(
                    orientation, for_size, out minimum, out natural, null, null
                );
            }
        }

        minimum_baseline = natural_baseline = -1;
    }

    public void set_has_new(Convey.Folder folder, bool has_new) {
        FolderEntry? entry = get_folder_entry(folder);
        if (entry != null) {
            entry.set_has_new(has_new);
        }

        if (folder.used_as == INBOX &&
            has_branch(inboxes_branch)) {
            entry = inboxes_branch.get_entry_for_account(folder.account);
            if (entry != null) {
                entry.set_has_new(has_new);
            }
        }
    }

    private FolderEntry? get_folder_entry(Convey.Folder folder) {
        AccountBranch? account_branch = account_branches.get(folder.account);
        return (account_branch == null ? null :
            account_branch.get_entry_for_path(folder.path));
    }

    public override bool accept_cursor_changed() {
        bool can_switch = true;
        var parent = get_root() as Application.MainWindow;
        if (parent != null) {
            can_switch = parent.close_composer(false);
        }
        return can_switch;
    }

    private void on_entry_selected(Sidebar.SelectableEntry selectable) {
        AbstractFolderEntry? entry = selectable as AbstractFolderEntry;
        if (entry != null) {
            this.selected = entry.folder;
            folder_selected(entry.folder);
        }
    }

    private void on_entry_activated(Sidebar.SelectableEntry selectable) {
        AbstractFolderEntry? entry = selectable as AbstractFolderEntry;
        if (entry != null) {
            folder_activated(entry.folder);
        }
    }

    public void set_user_folders_root_name(Convey.Account account, string name) {
        if (account_branches.has_key(account))
            account_branches.get(account).user_folder_group.rename(name);
    }

    public void add_folder(Application.FolderContext context) {
        Convey.Folder folder = context.folder;
        Convey.Account account = folder.account;
        bool had_folder = (get_folder_entry(folder) != null);

        if (!account_branches.has_key(account)) {
            this.account_branches.set(account, new AccountBranch(account));
            account.information.notify["ordinal"].connect(on_ordinal_changed);
        }

        var account_branch = this.account_branches.get(account);
        if (!has_branch(account_branch))
            graft(account_branch, account.information.ordinal);

        if (account_branches.size > 1 && !has_branch(inboxes_branch))
            graft(inboxes_branch, INBOX_ORDINAL); // The Inboxes branch comes first.
        if (folder.used_as == INBOX)
            inboxes_branch.add_inbox(context);

        account_branch.add_folder(context);

        if (!had_folder && get_folder_entry(folder) != null)
            scroll_to_top();
    }

    public void remove_folder(Application.FolderContext context) {
        Convey.Folder folder = context.folder;
        Convey.Account account = folder.account;

        var account_branch = this.account_branches.get(account);

        // If this is the current folder, unselect it.
        var entry = account_branch.get_entry_for_path(folder.path);

        // if not found or found but not selected, see if the folder is in the Inboxes branch
        if (has_branch(this.inboxes_branch) && (entry == null || !is_selected(entry))) {
            var inbox_entry = this.inboxes_branch.get_entry_for_account(account);
            if (inbox_entry != null && inbox_entry.folder == folder)
                entry = inbox_entry;
        }

        // if found and selected, report nothing is selected in preparation for its removal
        if (entry != null && is_selected(entry)) {
            deselect_folder();
        }

        // if Inbox, remove from inboxes branch, selected or not
        if (folder.used_as == INBOX)
            inboxes_branch.remove_inbox(account);

        account_branch.remove_folder(folder.path);
    }

    public void remove_account(Convey.Account account) {
        account.information.notify["ordinal"].disconnect(on_ordinal_changed);

        // If a folder on this account is selected, unselect it.
        if (this.selected != null &&
            this.selected.account == account) {
            deselect_folder();
        }

        AccountBranch? account_branch = account_branches.get(account);
        if (account_branch != null) {
            if (has_branch(account_branch))
                prune(account_branch);
            account_branches.unset(account);
        }

        inboxes_branch.remove_inbox(account);

        if (account_branches.size <= 1 && has_branch(inboxes_branch))
            prune(inboxes_branch);
    }

    public void select_folder(Convey.Folder to_select) {
        if (this.selected != to_select) {
            bool selected = false;
            if (to_select.used_as == INBOX) {
                selected = select_inbox(to_select.account);
            }

            if (!selected) {
                FolderEntry? entry = get_folder_entry(to_select);
                if (entry != null) {
                    place_cursor(entry, false);
                }
            }
        }
    }

    public bool select_inbox(Convey.Account account) {
        if (!has_branch(inboxes_branch))
            return false;

        InboxFolderEntry? entry = inboxes_branch.get_entry_for_account(account);
        if (entry == null)
            return false;

        place_cursor(entry, false);
        return true;
    }

    public void deselect_folder() {
        clear_selection();
        this.selected = null;
        folder_selected(null);
    }

    // Ctrl-for-copy is negotiated by GtkDropTarget in GTK4; see
    // Sidebar.Tree.on_drop_target_drop.

    public void set_search(Convey.Engine engine,
                           Convey.App.SearchFolder search_folder) {
        if (search_branch != null && has_branch(search_branch)) {
            // We already have a search folder.  If it's the same one, just
            // select it.  If it's a new search folder, remove the old one and
            // continue.
            if (search_folder == search_branch.get_search_folder()) {
                place_cursor(search_branch.get_root(), false);
                return;
            } else {
                remove_search();
            }
        }

        search_branch = new SearchBranch(search_folder, engine);
        graft(search_branch, SEARCH_ORDINAL);
        place_cursor(search_branch.get_root(), false);
    }

    public void remove_search() {
        if (search_branch != null) {
            prune(search_branch);
            search_branch = null;
        }
    }
    private void on_ordinal_changed() {
        if (account_branches.size <= 1)
            return;

        // Remove branches where the ordinal doesn't match the graft position.
        Gee.ArrayList<AccountBranch> branches_to_reorder = new Gee.ArrayList<AccountBranch>();
        foreach (AccountBranch branch in account_branches.values) {
            if (get_position_for_branch(branch) != branch.account.information.ordinal) {
                prune(branch);
                branches_to_reorder.add(branch);
            }
        }

        // Re-add branches with new positions.
        foreach (AccountBranch branch in branches_to_reorder)
            graft(branch, branch.account.information.ordinal);
    }

}
