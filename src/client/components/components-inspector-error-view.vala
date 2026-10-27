/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2019 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * A view that displays information about an application error.
 */
[GtkTemplate (ui = "/io/github/d3rpapah0d3n/GriabuntuMail/components-inspector-error-view.ui")]
public class Components.InspectorErrorView : Adw.Bin {


    [GtkChild] private unowned Gtk.TextView problem_text;

    private GriabuntuMail.ErrorContext error;
    private GriabuntuMail.AccountInformation? account;
    private GriabuntuMail.ServiceInformation? service;


    public InspectorErrorView(GriabuntuMail.ErrorContext error,
                              GriabuntuMail.AccountInformation? account,
                              GriabuntuMail.ServiceInformation? service) {
        this.error = error;
        this.account = account;
        this.service = service;

        this.problem_text.buffer.text = format_problem(
            Inspector.TextFormat.PLAIN
        );
    }

    public void save(GLib.DataOutputStream out,
                     Inspector.TextFormat format,
                     GLib.Cancellable? cancellable)
        throws GLib.Error {
            out.put_string(format_problem(format), cancellable);
    }

    private string format_problem(Inspector.TextFormat format) {
        string line_sep = format.get_line_separator();
        StringBuilder details = new StringBuilder();
        if (this.account != null) {
            details.append_printf(
                "Account identifier: %s", this.account.id
            );
            details.append(line_sep);
            details.append_printf(
                "Account provider: %s", this.account.service_provider.to_string()
            );
            details.append(line_sep);
        }
        if (this.service != null) {
            details.append_printf(
                "Service type: %s", this.service.protocol.to_string()
            );
            details.append(line_sep);
            details.append_printf(
                "Service host: %s", this.service.host
            );
            details.append(line_sep);
        }
        if (this.error == null) {
            details.append("No error reported");
            details.append(line_sep);
        } else {
            details.append_printf(
                "Error type: %s", this.error.format_error_type()
            );
            details.append(line_sep);
            details.append_printf(
                "Message: %s", this.error.thrown.message
            );
            details.append(line_sep);

            details.append_c('\n');
            details.append("Back trace:");
            details.append(line_sep);
            foreach (GriabuntuMail.ErrorContext.StackFrame frame in
                     this.error.backtrace) {
                details.append_printf(" * %s", frame.to_string());
                details.append(line_sep);
            }
        }
        return details.str;
    }

}
