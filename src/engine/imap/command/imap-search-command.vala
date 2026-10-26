/*
 * Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * A representation of the IMAP SEARCH command.
 *
 * See [[http://tools.ietf.org/html/rfc3501#section-6.4.4]].
 */
public class Convey.Imap.SearchCommand : Command {

    public const string NAME = "search";
    public const string UID_NAME = "uid search";

    public SearchCommand(SearchCriteria criteria,
                         GLib.Cancellable? should_send) {
        base(NAME, null, should_send);

        // Extend rather than append the criteria, so the top-level
        // criterion appear in the top-level list and not as a child
        // list
        this.args.extend(criteria);
    }

    public SearchCommand.uid(SearchCriteria criteria,
                             GLib.Cancellable? should_send) {
        base(UID_NAME, null, should_send);

        // Extend rather than append the criteria, so the top-level
        // criterion appear in the top-level list and not as a child
        // list
        this.args.extend(criteria);
    }

}
