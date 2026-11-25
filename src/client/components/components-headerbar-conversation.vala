/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright © 2017 Software Freedom Conservancy Inc.
 * Copyright © 2021 Michael Gratton <mike@vee.net>
 * Copyright © 2022 Cédric Bellegarde <cedric.bellegarde@adishatz.org>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */


/**
 * The conversations headerbar.
 *
 * @see Application.MainWindow
 */
[GtkTemplate (ui = "/io/github/d3rpapah0d3n/GriabuntuMail/components-headerbar-conversation.ui")]
public class Components.ConversationHeaderBar : Adw.Bin {

    public bool find_open { get; set; default = false; }

    public bool compact { get; set; default = false; }

    [GtkChild] public unowned ConversationActions left_actions;
    [GtkChild] public unowned ConversationActions right_actions;

    [GtkChild] private unowned Gtk.ToggleButton find_button;

    [GtkChild] private unowned Adw.HeaderBar conversation_header;
    // Keep a strong ref when it's temporarily removed
    private Adw.HeaderBar? _conversation_header = null;

    construct {
        this.bind_property(
            "find-open",
            this.find_button, "active",
            SYNC_CREATE | BIDIRECTIONAL
        );
    }

    public override void dispose() {
        this._conversation_header = null;
        base.dispose();
    }

    public void set_conversation_header(Adw.HeaderBar header)
            requires (header.parent == null) {
        this._conversation_header = null;
        header.hexpand = true;
        this.child = header;
    }

    public void remove_conversation_header(Adw.HeaderBar header) {
        this.child = this.conversation_header;
    }

    public void set_find_sensitive(bool is_sensitive) {
        this.find_button.sensitive = is_sensitive;
    }
}
