/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

public interface Sidebar.Entry : Object {


    public signal void entry_changed();


    public abstract string get_sidebar_name();

    public abstract string? get_sidebar_tooltip();

    public abstract string? get_sidebar_icon();

    public abstract int get_count();

    public abstract string to_string();

    /**
     * Whether a background operation is currently changing this entry.
     *
     * Busy entries are dimmed and show a spinner in place of their icon.
     */
    public virtual bool is_busy() {
        return false;
    }

    internal virtual void grafted(Sidebar.Tree tree) {
    }

    internal virtual void pruned(Sidebar.Tree tree) {
    }
}

public interface Sidebar.ExpandableEntry : Sidebar.Entry {
    public abstract bool expand_on_select();
}

public interface Sidebar.SelectableEntry : Sidebar.Entry {
}

public interface Sidebar.RenameableEntry : Sidebar.Entry {
    public abstract void rename(string new_name);

    // Return true to allow the user to rename the sidebar entry in the UI.
    public abstract bool is_user_renameable();
}

public interface Sidebar.EmphasizableEntry : Sidebar.Entry {
    public abstract bool is_emphasized();
}

public interface Sidebar.DestroyableEntry : Sidebar.Entry {
    public abstract void destroy_source();
}

public interface Sidebar.InternalDropTargetEntry : Sidebar.Entry {
    // Returns true if drop was successful
    public abstract bool internal_drop_received(Sidebar.Tree parent,
                                                Gdk.DragAction action);
}
