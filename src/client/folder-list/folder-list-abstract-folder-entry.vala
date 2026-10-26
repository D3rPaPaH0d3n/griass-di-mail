/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * Abstract base class for sidebar entries that represent folders.  This covers only
 * the basics needed for any type of folder, and is intended to work with both local
 * and remote folder types.
 */
public abstract class FolderList.AbstractFolderEntry : Convey.BaseObject, Sidebar.Entry, Sidebar.SelectableEntry {
    public Convey.Folder folder { get; private set; }

    /** The tree this entry is grafted onto, if any. */
    protected weak FolderList.Tree? tree = null;

    protected AbstractFolderEntry(Convey.Folder folder) {
        this.folder = folder;
    }

    private bool busy = false;

    /** Dims the row and shows a spinner while the folder is changing. */
    public void set_busy(bool busy) {
        if (this.busy != busy) {
            this.busy = busy;
            entry_changed();
        }
    }

    public override bool is_busy() {
        return this.busy;
    }

    internal override void grafted(Sidebar.Tree tree) {
        this.tree = tree as FolderList.Tree;
    }

    internal override void pruned(Sidebar.Tree tree) {
        this.tree = null;
    }

    public abstract string get_sidebar_name();

    public abstract string? get_sidebar_tooltip();

    public abstract string? get_sidebar_icon();

    public abstract int get_count();

    public virtual string to_string() {
        return "AbstractFolderEntry: " + get_sidebar_name();
    }
}

