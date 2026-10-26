/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * A generic interface for widgets that have a single composer child.
 */
public interface Composer.Container {

    /** The top-level window for the container, if any. */
    public abstract Gtk.ApplicationWindow? top_window { get; }

    /** The container's current composer, if any. */
    internal abstract Widget composer { get; set; }

    /** Causes the composer's top-level window to be presented. */
    public virtual void present() {
        Gtk.ApplicationWindow top = top_window;
        if (top != null) {
            top.present();
        }
    }

    /** Returns the top-level window's current focus widget, if any. */
    public virtual Gtk.Widget? get_focus() {
        Gtk.Widget? focus = null;
        Gtk.ApplicationWindow top = top_window;
        if (top != null) {
            focus = top.get_focus();
        }
        return focus;
    }

    /**
     * Removes the composer and destroys the container.
     */
    public abstract void close();

}
