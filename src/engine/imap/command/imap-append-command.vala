/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * A representation of the IMAP APPEND command.
 *
 * See [[http://tools.ietf.org/html/rfc3501#section-6.3.11]]
 */
public class GriabuntuMail.Imap.AppendCommand : Command {

    public const string NAME = "append";

    public AppendCommand(MailboxSpecifier mailbox,
                         MessageFlags? flags,
                         InternalDate? internal_date,
                         Memory.Buffer message,
                         GLib.Cancellable? should_send) {
        base(NAME, null, should_send);

        this.args.add(mailbox.to_parameter());

        if (flags != null && flags.size > 0) {
            this.args.add(flags.to_parameter());
        }

        if (internal_date != null) {
            this.args.add(internal_date.to_parameter());
        }

        this.args.add(new LiteralParameter(message));
    }

}
