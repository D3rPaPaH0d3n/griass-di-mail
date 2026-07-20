/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

/**
 * A signalled collection of NamedFlags.  Currently Convey uses these flags for enabling/disabling
 * options with email or contacts.
 */

public class Convey.NamedFlags : BaseObject, Gee.Hashable<Convey.NamedFlags> {
    protected Gee.Set<NamedFlag> list = new Gee.HashSet<NamedFlag>();

    public virtual signal void added(Gee.Collection<NamedFlag> flags) {
    }

    public virtual signal void removed(Gee.Collection<NamedFlag> flags) {
    }

    public NamedFlags() {
    }

    protected virtual void notify_added(Gee.Collection<NamedFlag> flags) {
        added(flags);
    }

    protected virtual void notify_removed(Gee.Collection<NamedFlag> flags) {
        removed(flags);
    }

    public bool contains(NamedFlag flag) {
        return list.contains(flag);
    }

    public bool contains_any(NamedFlags flags) {
        return Convey.traverse<NamedFlag>(list).any(f => flags.contains(f));
    }

    public Gee.Set<NamedFlag> get_all() {
        return list.read_only_view;
    }

    public virtual void add(NamedFlag flag) {
        if (!list.contains(flag)) {
            list.add(flag);
            notify_added(Convey.iterate<NamedFlag>(flag).to_array_list());
        }
    }

    public virtual void add_all(NamedFlags flags) {
        Gee.ArrayList<NamedFlag> added = Convey.traverse<NamedFlag>(flags.get_all())
            .filter(f => !list.contains(f))
            .to_array_list();

        list.add_all(added);
        notify_added(added);
    }

    public virtual bool remove(NamedFlag flag) {
        bool removed = list.remove(flag);
        if (removed)
            notify_removed(Convey.iterate<NamedFlag>(flag).to_array_list());

        return removed;
    }

    public virtual bool remove_all(NamedFlags flags) {
        Gee.ArrayList<NamedFlag> removed = Convey.traverse<NamedFlag>(flags.get_all())
            .filter(f => list.contains(f))
            .to_array_list();

        list.remove_all(removed);
        notify_removed(removed);

        return removed.size > 0;
    }

    public bool equal_to(Convey.NamedFlags other) {
        if (this == other)
            return true;

        if (list.size != other.list.size)
            return false;

        return Convey.traverse<NamedFlag>(list).all(f => other.contains(f));
    }

    public uint hash() {
        return Convey.String.stri_hash(to_string());
    }

    /** Formats the flags for serialising in the database. */
    public string serialise() {
        var builder = new GLib.StringBuilder();
        foreach (NamedFlag flag in this.list) {
            builder.append(flag.serialise());
            builder.append_c(' ');
        }
        return builder.str;
    }

    /** Formats the flags for debugging. */
    public string to_string() {
        string ret = "[";
        foreach (NamedFlag flag in list) {
            ret += flag.to_string() + " ";
        }

        return ret + "]";
    }
}
