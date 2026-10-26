/*
 * Copyright 2016 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * A placeholder image and message for empty views.
 */
[GtkTemplate (ui = "/net/donnybeelo/Convey/components-placeholder-pane.ui")]
public class Components.PlaceholderPane : Gtk.Box {


    public const string CLASS_HAS_TEXT = "convey-has-text";


    /** The icon name of the pane's image. */
    public string icon_name {
        owned get { return this.placeholder_image.icon_name; }
        set { this.placeholder_image.icon_name = value; }
    }

    /** The text of the pane's title label. */
    public string title {
        get { return this.title_label.get_text(); }
        set {
            this.title_label.set_text(value);
            update();
        }
    }

    /** The text of the pane's sub-title label. */
    public string subtitle {
        get { return this.subtitle_label.get_text(); }
        set {
            this.subtitle_label.set_text(value);
            update();
        }
    }

    [GtkChild] private unowned Gtk.Image placeholder_image;

    [GtkChild] private unowned Gtk.Label title_label;

    [GtkChild] private unowned Gtk.Label subtitle_label;


    private void update() {
        if (Convey.String.is_empty_or_whitespace(this.title_label.get_text())) {
            this.title_label.hide();
        }
        if (Convey.String.is_empty_or_whitespace(this.subtitle_label.get_text())) {
            this.subtitle_label.hide();
        }
        if (this.title_label.visible || this.subtitle_label.visible) {
            add_css_class(CLASS_HAS_TEXT);
        }
    }

}
