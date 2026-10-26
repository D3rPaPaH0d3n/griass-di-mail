/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

public enum Convey.Db.SynchronousMode {
    OFF = 0,
    NORMAL = 1,
    FULL = 2;

    public unowned string sql() {
        switch (this) {
            case OFF:
                return "off";

            case NORMAL:
                return "normal";

            case FULL:
            default:
                return "full";
        }
    }

    public static SynchronousMode parse(string str) {
        switch (str.down()) {
            case "off":
                return OFF;

            case "normal":
                return NORMAL;

            case "full":
            default:
                return FULL;
        }
    }
}

