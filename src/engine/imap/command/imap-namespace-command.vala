/*
 * Copyright 2016 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * The RFC 2342 NAMESPACE command.
 *
 * Determines the mailbox name prefix and hierarchy delimiter for the
 * personal, other user's and public namespaces.
 *
 * See [[https://tools.ietf.org/html/rfc2342|RFC 2342]] for details.
 */
public class Convey.Imap.NamespaceCommand : Command {

    public const string NAME = "NAMESPACE";

    public NamespaceCommand(GLib.Cancellable? should_send) {
        base(NAME, null, should_send);
    }

}
