/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2016 Software Freedom Conservancy Inc.
 * Copyright 2019 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * A container for full-height paned composers in the main window.
 *
 * Adding a composer to this container places it in {@link
 * Widget.PresentationMode.PANED} mode.
 */
public class Composer.Box : Gtk.Frame, Composer.Container {

    static construct {
        set_css_name("griabuntu-mail-composer-box");
    }


    /** {@inheritDoc} */
    public Gtk.ApplicationWindow? top_window {
        get { return get_root() as Gtk.ApplicationWindow; }
    }

    /** {@inheritDoc} */
    internal Widget composer { get; set; }

    private Components.ConversationHeaderBar headerbar { get; private set; }


    /** Emitted when the container is closed. */
    public signal void vanished();


    public Box(Widget composer, Components.ConversationHeaderBar headerbar) {
        this.composer = composer;
        this.composer.set_mode(PANED);

        this.headerbar = headerbar;
        this.headerbar.set_conversation_header(composer.header.headerbar);

        add_css_class("griabuntu-mail-composer-box");
        this.halign = Gtk.Align.FILL;
        this.vexpand = true;
        this.vexpand_set = true;

        this.child = this.composer;
        show();
    }

    /** {@inheritDoc} */
    public void close() {
        vanished();

        this.headerbar.remove_conversation_header(composer.header.headerbar);
        this.child = null;
        destroy();
    }

}
