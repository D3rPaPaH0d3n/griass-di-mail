/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright © 2020 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * Enables plugins to report ongoing status messages.
 *
 * The info bar supports two text descriptions, a short (approximately
 * 20 charters at most) status message, and a possibly longer
 * explanation of what is happening.
 */
public class Plugin.InfoBar : GriabuntuMail.BaseObject {


    /** Emitted when the close button is activated. */
    public signal void close_activated();

    /**
     * A short, human-readable status message.
     *
     * This should ideally be less than 20 characters long.
     */
    public string status { get; set; }

    /**
     * An optional, longer human-readable explanation of the status.
     *
     * This provides additional information and context for {@link
     * status}.
     */
    public string? description { get; set; }

    /** Determines if a close button is displayed by the info bar. */
    public bool show_close_button { get; set; default = false; }

    /**
     * An optional primary button for the info bar.
     *
     * The info bar is not automatically dismissed when the button is
     * clicked. If it should be hidden then the action's handler
     * should explicitly do so by calling the appropriate context
     * object's method, such as {@link
     * FolderContext.remove_folder_info_bar}.
     */
    public Actionable? primary_button { get; set; default = null; }

    /**
     * Optional secondary buttons for the info bar.
     *
     * Secondary buttons are either placed before the primary button,
     * or on a drop-down menu under it, depending on available space.
     *
     * The info bar is not automatically dismissed when a button is
     * clicked. If it should be hidden then the action's handler
     * should explicitly do so by calling the appropriate context
     * object's method, such as {@link
     * FolderContext.remove_folder_info_bar}.
     */
    public Gee.BidirList<Actionable> secondary_buttons {
        get; private set; default = new Gee.LinkedList<Actionable>();
    }

    /** Constructs a new info bar with the given status. */
    public InfoBar(string status,
                   string? description = null) {
        this.status = status;
        this.description = description;
    }

}
