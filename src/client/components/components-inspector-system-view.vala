/*
 * Copyright 2019 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * A view that displays system and library information.
 */
[GtkTemplate (ui = "/net/donnybeelo/Convey/components-inspector-system-view.ui")]
public class Components.InspectorSystemView : Gtk.Box {


    [GtkChild] private unowned Gtk.ListBox system_list;

    private Gee.Collection<Application.Client.RuntimeDetail?> details;


    public InspectorSystemView(Application.Client application) {
        this.details = application.get_runtime_information();
        foreach (Application.Client.RuntimeDetail? detail in this.details) {
            var row = new Adw.ActionRow();
            row.add_css_class("property");
            row.title = detail.name;
            row.subtitle = detail.value;
            this.system_list.append(row);
        }
    }

    public void save(GLib.DataOutputStream out,
                     Inspector.TextFormat format,
                     GLib.Cancellable? cancellable)
        throws GLib.Error {
        string line_sep = format.get_line_separator();
        foreach (Application.Client.RuntimeDetail? detail in this.details) {
            out.put_string(detail.name);
            out.put_string(": ");
            out.put_string(detail.value);
            out.put_string(line_sep);
        }
    }

}
