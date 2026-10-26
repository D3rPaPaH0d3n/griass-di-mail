/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * See [[http://tools.ietf.org/html/rfc3501#section-6.2.3]]
 */

public class Convey.Imap.LoginCommand : Command {

    public const string NAME = "login";

    public LoginCommand(string user,
                        string pass,
                        GLib.Cancellable? should_send) {
        base(NAME, { user, pass }, should_send);
    }

    public override string to_string() {
        return "%s %s <user> <pass>".printf(tag.to_string(), name);
    }

}
