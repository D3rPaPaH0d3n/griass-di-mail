/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * A branch containing the single "All Inboxes" entry, which sits above
 * the per-account Inboxes branch.
 */
public class FolderList.AllInboxesBranch : Sidebar.RootOnlyBranch {

    public AllInboxesBranch() {
        base(new AllInboxesEntry());
    }

    public AllInboxesEntry get_inboxes_entry() {
        return (AllInboxesEntry) get_root();
    }

}

/**
 * The entry for the combined view of every account's inbox.
 *
 * Unlike every other selectable entry in the folder list this one has
 * no folder of its own: it stands for the set of inboxes, which the
 * main window loads with one conversation monitor per account.
 */
public class FolderList.AllInboxesEntry : GriabuntuMail.BaseObject,
    Sidebar.Entry, Sidebar.SelectableEntry {


    private Gee.Map<GriabuntuMail.Account, Application.FolderContext> inboxes =
        new Gee.HashMap<GriabuntuMail.Account, Application.FolderContext>();


    public void add_inbox(Application.FolderContext context) {
        if (this.inboxes.has_key(context.folder.account)) {
            remove_inbox(context.folder.account);
        }
        this.inboxes.set(context.folder.account, context);
        connect_counts(context, true);
        entry_changed();
    }

    public void remove_inbox(GriabuntuMail.Account account) {
        Application.FolderContext? context = this.inboxes.get(account);
        if (context == null) {
            return;
        }
        connect_counts(context, false);
        this.inboxes.unset(account);
        entry_changed();
    }

    /** The inboxes this entry stands for. */
    public Gee.Collection<GriabuntuMail.Folder> get_inboxes() {
        var folders = new Gee.ArrayList<GriabuntuMail.Folder>();
        foreach (var context in this.inboxes.values) {
            folders.add(context.folder);
        }
        return folders;
    }

    public string get_sidebar_name() {
        return _("All Inboxes");
    }

    public string? get_sidebar_tooltip() {
        int total = 0;
        foreach (var context in this.inboxes.values) {
            total += context.folder.properties.email_total;
        }
        return ngettext("%d message", "%d messages", total).printf(total);
    }

    public string? get_sidebar_icon() {
        return "mail-inbox-symbolic";
    }

    public int get_count() {
        int count = 0;
        foreach (var context in this.inboxes.values) {
            switch (context.displayed_count) {
            case TOTAL:
                count += context.folder.properties.email_total;
                break;

            case UNREAD:
                count += context.folder.properties.email_unread;
                break;

            default:
                break;
            }
        }
        return count;
    }

    public string to_string() {
        return "AllInboxesEntry";
    }

    private void connect_counts(Application.FolderContext context, bool connect) {
        var properties = context.folder.properties;
        if (connect) {
            properties.notify[
                GriabuntuMail.FolderProperties.PROP_NAME_EMAIL_TOTAL
            ].connect(on_counts_changed);
            properties.notify[
                GriabuntuMail.FolderProperties.PROP_NAME_EMAIL_UNREAD
            ].connect(on_counts_changed);
        } else {
            properties.notify[
                GriabuntuMail.FolderProperties.PROP_NAME_EMAIL_TOTAL
            ].disconnect(on_counts_changed);
            properties.notify[
                GriabuntuMail.FolderProperties.PROP_NAME_EMAIL_UNREAD
            ].disconnect(on_counts_changed);
        }
    }

    private void on_counts_changed() {
        entry_changed();
    }

}
