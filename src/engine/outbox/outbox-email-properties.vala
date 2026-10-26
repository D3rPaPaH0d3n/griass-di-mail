/*
 *  Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

private class Convey.Outbox.EmailProperties : Convey.EmailProperties {


    public EmailProperties(GLib.DateTime date_received, long total_bytes) {
        base(date_received, total_bytes);
    }

    public override string to_string() {
        return "Outbox.Properties";
    }

}
