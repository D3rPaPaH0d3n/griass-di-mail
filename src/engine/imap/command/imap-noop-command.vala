/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * See [[http://tools.ietf.org/html/rfc3501#section-6.1.2]]
 *
 * @see IdleCommand
 */

public class GriabuntuMail.Imap.NoopCommand : Command {

    public const string NAME = "noop";

    public NoopCommand(GLib.Cancellable? should_send) {
        base(NAME, null, should_send);
    }

}
