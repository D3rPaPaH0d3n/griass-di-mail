/* Copyright 2022 Cédric Bellegarde <cedric.bellegarde@adishatz.org>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

[GtkTemplate (ui = "/net/donnybeelo/Convey/folder-popover-row.ui")]
public class FolderPopoverRow : Gtk.ListBoxRow {

    [GtkChild] private unowned Gtk.Image image;
    [GtkChild] private unowned Gtk.Label label;

    public FolderPopoverRow(Application.FolderContext context, Gee.HashMap<string,string> map) {
        string[] parts = context.folder.path.as_array();

        if (parts.length > 0 && map.has_key(parts[0])) {
            parts[0] = map[parts[0]];
        }

        for (int i = 0; i < parts.length; i++) {
            // The leaf is shown under the name the rest of the UI uses
            parts[i] = GLib.Markup.escape_text(
                (i == parts.length - 1) ? context.display_name : parts[i]
            );
        }

        this.set_data("folder", context.folder);
        this.image.icon_name = context.icon_name;

        this.label.set_markup(
            parts.length > 0
            ? string.joinv("<span alpha='30%'> / </span>", parts)
            : GLib.Markup.escape_text(context.display_name)
        );
        this.label.query_tooltip.connect(Util.Gtk.query_tooltip_label);
    }
}
