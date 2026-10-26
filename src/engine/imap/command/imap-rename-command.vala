/*
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * The RFC 3501 RENAME command.
 *
 * See [[http://tools.ietf.org/html/rfc3501#section-6.3.5]]
 */
public class Convey.Imap.RenameCommand : Command {

    public const string NAME = "RENAME";

    public RenameCommand(MailboxSpecifier from,
                         MailboxSpecifier to,
                         GLib.Cancellable? should_send) {
        base(NAME, null, should_send);
        this.args.add(from.to_parameter());
        this.args.add(to.to_parameter());
    }

}
