/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

public class FolderList.Tree : Sidebar.Tree, GriabuntuMail.BaseInterface {


    private const int ALL_INBOX_ORDINAL = -3; // First account branch is zero
    private const int INBOX_ORDINAL = -2;
    private const int SEARCH_ORDINAL = -1;


    public signal void folder_selected(GriabuntuMail.Folder? folder);
    public signal void all_inboxes_selected();

    /** Fired when the user collapses or expands a part of the tree. */
    public signal void expansion_changed();

    /** Fired on a deliberate poke at the sidebar. */
    public signal void user_interacted();
    public signal void folder_activated(GriabuntuMail.Folder? folder);
    public signal void all_inboxes_activated();
    public signal void copy_conversation(GriabuntuMail.Folder folder);
    public signal void move_conversation(GriabuntuMail.Folder folder);
    public signal void folder_rename(GriabuntuMail.Folder folder, string new_name);
    public signal void folder_delete(GriabuntuMail.Folder folder);

    public GriabuntuMail.Folder? selected { get ; private set; default = null; }

    private Gee.HashMap<GriabuntuMail.Account, AccountBranch> account_branches
        = new Gee.HashMap<GriabuntuMail.Account, AccountBranch>();
    private InboxesBranch inboxes_branch = new InboxesBranch();
    private AllInboxesBranch all_inboxes_branch = new AllInboxesBranch();
    private SearchBranch? search_branch = null;
    private Gtk.PopoverMenu? inboxes_context_menu = null;
    private Gee.Set<GriabuntuMail.Folder> drag_sources =
        new Gee.HashSet<GriabuntuMail.Folder>();
    private Gee.Set<string> collapsed = new Gee.HashSet<string>();
    private uint startup_scroll_timeout = 0;
    private bool startup_scroll_done = false;
    private Gtk.Adjustment? pinned_vadjustment = null;


    public Tree() {
        base();
        base_ref();
        set_activate_on_single_click(true);
        entry_selected.connect(on_entry_selected);
        entry_expansion_changed.connect(on_entry_expansion_changed);
        entry_activated.connect(on_entry_activated);
        this.notify["vadjustment"].connect(update_startup_pin);

        // Any deliberate poke at the sidebar ends the startup scroll pin.
        var scroll = new Gtk.EventControllerScroll(
            Gtk.EventControllerScrollFlags.BOTH_AXES
        ) { propagation_phase = Gtk.PropagationPhase.CAPTURE };
        scroll.scroll.connect((dx, dy) => {
            on_user_poke();
            return false;
        });
        add_controller(scroll);

        var poke = new Gtk.GestureClick() {
            button = 0,
            propagation_phase = Gtk.PropagationPhase.CAPTURE
        };
        poke.pressed.connect((n, x, y) => on_user_poke());
        add_controller(poke);

        var keys = new Gtk.EventControllerKey() {
            propagation_phase = Gtk.PropagationPhase.CAPTURE
        };
        keys.key_pressed.connect((kv, kc, state) => {
            on_user_poke();
            return false;
        });
        add_controller(keys);

        this.visible = true;
    }

    ~Tree() {
        release_startup_pin();
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

    public void set_has_new(GriabuntuMail.Folder folder, bool has_new) {
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

    /** Dims a folder's row and spins it while the folder is changing. */
    public void set_folder_busy(GriabuntuMail.Folder folder, bool busy) {
        FolderEntry? entry = get_folder_entry(folder);
        if (entry != null) {
            entry.set_busy(busy);
        }

        if (folder.used_as == INBOX && has_branch(this.inboxes_branch)) {
            var inbox = this.inboxes_branch.get_entry_for_account(folder.account);
            if (inbox != null) {
                inbox.set_busy(busy);
            }
        }
    }

    /**
     * Shows a placeholder row for a folder that is being created.
     *
     * Returns the placeholder, to be handed back to {@link
     * remove_pending_folder} once the real folder exists or the
     * attempt has failed.
     */
    public PendingFolderEntry? add_pending_folder(GriabuntuMail.Account account,
                                                  string name,
                                                  GriabuntuMail.Folder? parent = null) {
        var branch = this.account_branches.get(account);
        if (branch == null) {
            return null;
        }
        var entry = new PendingFolderEntry(name, Util.I18n.uses_labels(account));
        branch.add_pending_folder(
            entry, (parent != null) ? parent.path : null
        );
        return entry;
    }

    public void remove_pending_folder(GriabuntuMail.Account account,
                                      PendingFolderEntry entry) {
        var branch = this.account_branches.get(account);
        if (branch != null) {
            branch.remove_pending_folder(entry);
        }
    }

    /** Returns the account whose branch contains this entry, if any. */
    public GriabuntuMail.Account? get_account_for_entry(Sidebar.Entry entry) {
        foreach (var branch in this.account_branches.values) {
            if (branch.has_entry(entry)) {
                return branch.account;
            }
        }
        return null;
    }

    /** Menu shown for the Inboxes section, which has no folders to manage. */
    public void set_inboxes_context_menu(Gtk.PopoverMenu menu) {
        this.inboxes_context_menu = menu;
    }

    protected override Gtk.PopoverMenu? get_context_menu(Sidebar.Entry? entry) {
        if (entry == null) {
            return null;
        }
        if (is_inboxes_entry(entry)) {
            return this.inboxes_context_menu;
        }
        // Anything outside an account branch (eg. search) has no
        // folders to manage
        return (get_account_for_entry(entry) != null)
            ? base.get_context_menu(entry)
            : null;
    }

    // Keep the folder groups so the remaining folders stay placed, and
    // the name of any account the mail can actually be filed into.
    protected override bool entry_accepts_drop(Sidebar.Entry entry) {
        if (entry is Sidebar.Header) {
            foreach (var branch in this.account_branches.values) {
                if (branch.get_root() == entry) {
                    return has_drop_target(branch);
                }
            }
            return false;
        }
        if (entry is Sidebar.Grouping) {
            return true;
        }
        var folder_entry = entry as FolderEntry;
        return (
            folder_entry != null &&
            !(entry is InboxFolderEntry) &&
            accepts_drop(folder_entry.folder)
        );
    }

    /** Folders the mail currently being dragged came from. */
    public void set_drag_sources(Gee.Collection<GriabuntuMail.Folder> sources) {
        this.drag_sources.clear();
        this.drag_sources.add_all(sources);
    }

    /**
     * Determines if dragged mail can be filed into the given folder.
     *
     * The folder must be a user destination in the same account as the
     * selected folder, or, when nothing is selected, as every one of
     * the drag sources.
     */
    public bool accepts_drop(GriabuntuMail.Folder folder) {
        if (!Application.FolderContext.is_user_destination(folder)) {
            return false;
        }

        if (this.selected != null) {
            return (
                folder != this.selected &&
                folder.account == this.selected.account
            );
        }

        GriabuntuMail.Account? account = null;
        foreach (var source in this.drag_sources) {
            if (source == folder ||
                (account != null && account != source.account)) {
                return false;
            }
            account = source.account;
        }
        return account != null && folder.account == account;
    }

    /** Restores which parts of the tree were collapsed last session. */
    public void set_collapsed(string[] keys) {
        this.collapsed.clear();
        foreach (var key in keys) {
            this.collapsed.add(key);
        }
    }

    /** The parts of the tree the user has collapsed. */
    public string[] get_collapsed() {
        // Built by appending so the array is null terminated, as
        // g_settings_set_strv requires
        string[] keys = {};
        foreach (var key in this.collapsed) {
            keys += key;
        }
        return keys;
    }

    protected override bool is_collapsed(Sidebar.Entry entry) {
        string? key = expansion_key(entry);
        return key != null && key in this.collapsed;
    }

    private void on_entry_expansion_changed(Sidebar.Entry entry,
                                            bool expanded) {
        string? key = expansion_key(entry);
        if (key == null) {
            return;
        }

        if (expanded) {
            this.collapsed.remove(key);
        } else {
            this.collapsed.add(key);
        }
        expansion_changed();
    }

    // A name that survives restarts: the account an entry belongs to,
    // plus its folder path or group name.
    private string? expansion_key(Sidebar.Entry entry) {
        if (has_branch(this.inboxes_branch) &&
            this.inboxes_branch.get_root() == entry) {
            return "inboxes";
        }

        foreach (var branch in this.account_branches.values) {
            string id = branch.account.information.id;
            if (branch.get_root() == entry) {
                return id;
            }
            if (branch.has_entry(entry)) {
                var folder_entry = entry as AbstractFolderEntry;
                return "%s:%s".printf(
                    id,
                    folder_entry != null
                    ? folder_entry.folder.path.to_string()
                    : entry.get_sidebar_name()
                );
            }
        }
        return null;
    }

    private bool has_drop_target(AccountBranch branch) {
        foreach (var entry in branch.folder_entries.values) {
            if (accepts_drop(entry.folder)) {
                return true;
            }
        }
        return false;
    }

    private bool is_inboxes_entry(Sidebar.Entry entry) {
        return (
            entry is InboxFolderEntry ||
            (has_branch(this.inboxes_branch) &&
             this.inboxes_branch.get_root() == entry)
        );
    }

    private FolderEntry? get_folder_entry(GriabuntuMail.Folder folder) {
        AccountBranch? account_branch = account_branches.get(folder.account);
        return (account_branch == null ? null :
            account_branch.get_entry_for_path(folder.path));
    }

    public override bool accept_cursor_changed(Sidebar.SelectableEntry entry) {
        var parent = get_root() as Application.MainWindow;
        var folder_entry = entry as AbstractFolderEntry;
        if (parent == null ||
            (folder_entry != null && folder_entry.folder == parent.selected_folder) ||
            (entry is AllInboxesEntry && parent.all_inboxes)) {
            return true;
        }
        return parent.close_composer(false);
    }

    private void on_entry_selected(Sidebar.SelectableEntry selectable) {
        AbstractFolderEntry? entry = selectable as AbstractFolderEntry;
        if (entry != null) {
            this.selected = entry.folder;
            folder_selected(entry.folder);
        } else if (selectable is AllInboxesEntry) {
            this.selected = null;
            all_inboxes_selected();
        }
    }

    private void on_entry_activated(Sidebar.SelectableEntry selectable) {
        AbstractFolderEntry? entry = selectable as AbstractFolderEntry;
        if (entry != null) {
            folder_activated(entry.folder);
        } else if (selectable is AllInboxesEntry) {
            all_inboxes_activated();
        }
    }

    public void set_user_folders_root_name(GriabuntuMail.Account account, string name) {
        if (account_branches.has_key(account))
            account_branches.get(account).user_folder_group.rename(name);
    }

    public void add_folder(Application.FolderContext context) {
        GriabuntuMail.Folder folder = context.folder;
        GriabuntuMail.Account account = folder.account;

        if (!account_branches.has_key(account)) {
            this.account_branches.set(account, new AccountBranch(account));
            account.information.notify["ordinal"].connect(on_ordinal_changed);
        }

        var account_branch = this.account_branches.get(account);
        if (!has_branch(account_branch))
            graft(account_branch, account.information.ordinal);

        if (account_branches.size > 1 && !has_branch(inboxes_branch)) {
            graft(inboxes_branch, INBOX_ORDINAL); // The Inboxes branch comes first.
            graft(all_inboxes_branch, ALL_INBOX_ORDINAL);
        }
        if (folder.used_as == INBOX) {
            inboxes_branch.add_inbox(context);
            all_inboxes_branch.get_inboxes_entry().add_inbox(context);
        }

        account_branch.add_folder(context);

        queue_startup_scroll();
    }

    // Folders trickle in for seconds after launch, and the startup
    // folder selection scrolls itself into view once its account
    // finishes opening, leaving the list part-way down. Hold it at the
    // top until the user actually touches the sidebar.
    private void queue_startup_scroll() {
        if (this.startup_scroll_done || this.startup_scroll_timeout != 0)
            return;

        update_startup_pin();
        this.startup_scroll_timeout = GLib.Timeout.add(3000, () => {
            this.startup_scroll_timeout = 0;
            scroll_to_top();
            release_startup_pin();
            return GLib.Source.REMOVE;
        });
    }

    private void on_user_poke() {
        release_startup_pin();
        user_interacted();
    }

    private void release_startup_pin() {
        if (this.startup_scroll_timeout != 0) {
            GLib.Source.remove(this.startup_scroll_timeout);
            this.startup_scroll_timeout = 0;
        }
        this.startup_scroll_done = true;
        update_startup_pin();
    }

    private void update_startup_pin() {
        Gtk.Adjustment? wanted = null;
        if (!this.startup_scroll_done)
            wanted = this.vadjustment;

        if (this.pinned_vadjustment == wanted)
            return;

        if (this.pinned_vadjustment != null) {
            this.pinned_vadjustment.changed.disconnect(on_pinned_scroll);
            this.pinned_vadjustment.value_changed.disconnect(on_pinned_scroll);
        }
        this.pinned_vadjustment = wanted;
        if (this.pinned_vadjustment != null) {
            this.pinned_vadjustment.changed.connect(on_pinned_scroll);
            this.pinned_vadjustment.value_changed.connect(on_pinned_scroll);
            on_pinned_scroll();
        }
    }

    private void on_pinned_scroll() {
        var adj = this.pinned_vadjustment;
        if (adj != null && adj.value != adj.lower)
            adj.value = adj.lower;
    }

    public void remove_folder(Application.FolderContext context) {
        GriabuntuMail.Folder folder = context.folder;
        GriabuntuMail.Account account = folder.account;

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
        if (folder.used_as == INBOX) {
            inboxes_branch.remove_inbox(account);
            all_inboxes_branch.get_inboxes_entry().remove_inbox(account);
        }

        account_branch.remove_folder(folder.path);
    }

    public void remove_account(GriabuntuMail.Account account) {
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
        all_inboxes_branch.get_inboxes_entry().remove_inbox(account);

        if (account_branches.size <= 1 && has_branch(inboxes_branch)) {
            prune(inboxes_branch);
            prune(all_inboxes_branch);
        }
    }

    public void select_folder(GriabuntuMail.Folder to_select) {
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

    public bool select_inbox(GriabuntuMail.Account account) {
        if (!has_branch(inboxes_branch))
            return false;

        InboxFolderEntry? entry = inboxes_branch.get_entry_for_account(account);
        if (entry == null)
            return false;

        place_cursor(entry, false);
        return true;
    }

    /** Selects the combined inbox entry, if it is present. */
    public bool select_all_inboxes() {
        if (!has_branch(this.all_inboxes_branch))
            return false;

        this.selected = null;
        var root = this.all_inboxes_branch.get_root();
        if (!is_selected(root))
            place_cursor(root, false);
        return true;
    }

    /** The inboxes the combined entry stands for. */
    public Gee.Collection<GriabuntuMail.Folder> get_all_inboxes() {
        return this.all_inboxes_branch.get_inboxes_entry().get_inboxes();
    }

    public void deselect_folder() {
        clear_selection();
        this.selected = null;
        folder_selected(null);
    }

    // Ctrl-for-copy is negotiated by GtkDropTarget in GTK4; see
    // Sidebar.Tree.on_drop_target_drop.

    public void set_search(GriabuntuMail.Engine engine,
                           GriabuntuMail.App.SearchFolder search_folder) {
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
