/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2018 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * The RFC 3501 DELETE command.
 *
 * Deletes the given mailbox. Per the RFC, this must not be used to
 * delete mailboxes with child (inferior) mailboxes and that also are
 * marked \Noselect.
 *
 * See [[http://tools.ietf.org/html/rfc3501#section-6.3.4]]
 */
public class GriabuntuMail.Imap.DeleteCommand : Command {

    public const string NAME = "DELETE";

    public DeleteCommand(MailboxSpecifier mailbox,
                         GLib.Cancellable? should_send) {
        base(NAME, null, should_send);
        this.args.add(mailbox.to_parameter());
    }

}
