/*
 * Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * See [[http://tools.ietf.org/html/rfc3501#section-6.4.7]]
 */
public class Convey.Imap.CopyCommand : Command {

    public const string NAME = "copy";
    public const string UID_NAME = "uid copy";

    public CopyCommand(MessageSet message_set,
                       MailboxSpecifier destination,
                       GLib.Cancellable? should_send) {
        base(message_set.is_uid ? UID_NAME : NAME, null, should_send);

        this.args.add(message_set.to_parameter());
        this.args.add(destination.to_parameter());
    }
}
