/*
 * Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * See [[http://tools.ietf.org/html/rfc3501#section-6.4.3]] and
 * [[http://tools.ietf.org/html/rfc4315#section-2.1]]
 */
public class Convey.Imap.ExpungeCommand : Command {

    public const string NAME = "expunge";
    public const string UID_NAME = "uid expunge";

    public ExpungeCommand(GLib.Cancellable? should_send) {
        base(NAME, null, should_send);
    }

    public ExpungeCommand.uid(MessageSet message_set,
                              GLib.Cancellable? should_send) {
        base(UID_NAME, null, should_send);
        assert(message_set.is_uid);
        this.args.add(message_set.to_parameter());
    }

}
