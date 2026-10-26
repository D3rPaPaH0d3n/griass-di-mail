/*
 * Copyright 2017 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

public class Mock.EmailProperties : Convey.EmailProperties {


    public EmailProperties(GLib.DateTime received) {
        base(received, 0);
    }

    public override string to_string() {
        return "Mock.EmailProperties: %s/%lli".printf(
            this.date_received.to_string(), this.total_bytes
        );
    }

}
