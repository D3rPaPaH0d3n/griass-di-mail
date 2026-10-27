/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright © 2017,2020 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * Displays a Griabuntu Mail problem report as an info bar.
 */
public class Components.ProblemReportInfoBar : InfoBar {


    private enum ResponseType { DETAILS, RETRY; }

    /** If reporting a problem, returns the problem report else null. */
    public GriabuntuMail.ProblemReport report { get; private set; }

    /** Emitted when the user clicks the Retry button, if any. */
    public signal void retry();


    public ProblemReportInfoBar(GriabuntuMail.ProblemReport report) {
        Gtk.MessageType type = Gtk.MessageType.WARNING;
        string title = "";
        string descr = "";
        string? retry = null;

        if (report is GriabuntuMail.AccountProblemReport) {
            GriabuntuMail.AccountProblemReport account_report =
                (GriabuntuMail.AccountProblemReport) report;
            string account_name = account_report.account.display_name;

            // Translators: Info bar title for a generic account
            // problem.
            title = _("Account problem");
            // Translators: Info bar sub-title for a generic account
            // problem. String substitution is the account name.
            descr = _(
                "Griabuntu Mail has encountered a problem with %s."
            ).printf(account_name);

            if (report is GriabuntuMail.ServiceProblemReport) {
                GriabuntuMail.ServiceProblemReport service_report =
                    (GriabuntuMail.ServiceProblemReport) report;

                switch (service_report.service.protocol) {
                case IMAP:
                    // Translators: Info bar sub-title for a generic
                    // account problem. String substitution is the
                    // account name.
                    descr = _(
                        "Griabuntu Mail encountered a problem checking mail for %s."
                    ).printf(account_name);

                    // Translators: Tooltip label for Retry button
                    retry = _("Try reconnecting");
                    break;

                case SMTP:
                    // Translators: Info bar title for an outgoing
                    // account problem. String substitution is the
                    // account name
                    descr = _(
                        "Griabuntu Mail encountered a problem sending email for %s."
                    ).printf(account_name);

                    // Translators: Tooltip label for Retry button
                    retry = _("Retry sending queued messages");
                    break;
                }
            }
        } else {
            // Translators: Info bar title for a generic application
            // problem.
            title = _("Griabuntu Mail has encountered a problem");
            // Translators: Info bar sub-title for a generic
            // application problem.
            descr = _(
                "Please report the details if it persists."
            );
        }

        base(title, descr);
        this.message_type = type;
        this.report = report;
        this.show_close_button = (retry == null);

        this.response.connect(on_info_bar_response);

        if (this.report.error != null) {
            // Translators: Button label for viewing technical details
            // for a problem report.
            Gtk.Button details = add_button(_("_Details"), ResponseType.DETAILS);
            // Translators: Tooltip for viewing technical details for
            // a problem report.
            details.tooltip_text = _("View technical details about the error");
        }

        if (retry != null) {
            // Translators: Button label for retrying a server
            // connection
            Gtk.Button retry_btn = add_button(_("_Retry"), ResponseType.RETRY);
            retry_btn.tooltip_text = retry;
        }
    }

    private void show_details() {
        var main = get_root() as Application.MainWindow;
        if (main != null) {
            var dialog = new Dialogs.ProblemDetailsDialog(
                main.application,
                this.report
            );
            dialog.present(main);
        }
    }

    private void on_info_bar_response(int response) {
        switch(response) {
        case ResponseType.DETAILS:
            show_details();
            break;

        case ResponseType.RETRY:
            retry();
            this.revealed = false;
            break;

        default:
            this.revealed = false;
            break;
        }
    }

}
