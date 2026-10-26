/*
 * Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * See [[http://tools.ietf.org/html/rfc3501#section-6.3.1]]
 *
 * @see ExamineCommand
 */
public class Convey.Imap.SelectCommand : Command {

    public const string NAME = "select";

    public MailboxSpecifier mailbox { get; private set; }

    public SelectCommand(MailboxSpecifier mailbox,
                         GLib.Cancellable? should_send) {
        base(NAME, null, should_send);
        this.mailbox = mailbox;
        this.args.add(mailbox.to_parameter());
    }

}
