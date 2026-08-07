/*
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

/**
 * A placeholder row for a folder that is still being created.
 *
 * It is never selectable and always reports itself as busy, so the tree
 * renders it dimmed with a spinner until the real folder arrives.
 */
public class FolderList.PendingFolderEntry : Convey.BaseObject, Sidebar.Entry {

    public string name { get; private set; }

    private bool labels;

    public PendingFolderEntry(string name, bool labels) {
        this.name = name;
        this.labels = labels;
    }

    public string get_sidebar_name() {
        return this.name;
    }

    public string? get_sidebar_tooltip() {
        // Translators: Tooltip for a folder that is being created, and
        // the label equivalent
        return this.labels ? _("Creating label…") : _("Creating folder…");
    }

    public string? get_sidebar_icon() {
        return this.labels ? "tag-symbolic" : "folder-symbolic";
    }

    public int get_count() {
        return 0;
    }

    public override bool is_busy() {
        return true;
    }

    public string to_string() {
        return "PendingFolderEntry: " + this.name;
    }

}
