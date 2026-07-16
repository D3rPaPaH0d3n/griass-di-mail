/*
 * Copyright 2026 Daniel Elia <d.elia@outlook.com>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

internal class Geary.Graph.EmailProperties : Geary.EmailProperties {

    public EmailProperties(GLib.DateTime date_received, int64 total_bytes) {
        base(date_received, total_bytes);
    }

    public override string to_string() {
        return "%s:%lld".printf(this.date_received.to_string(), this.total_bytes);
    }

}
