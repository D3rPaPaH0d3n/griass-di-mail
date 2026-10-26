/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

public enum Convey.Db.TransactionOutcome {
    ROLLBACK = 0,
    COMMIT = 1,

    // coarse synonyms
    SUCCESS = COMMIT,
    FAILURE = ROLLBACK,
    DONE = COMMIT;

    public unowned string sql() {
        switch (this) {
            case COMMIT:
                return "COMMIT TRANSACTION";

            case ROLLBACK:
            default:
                return "ROLLBACK TRANSACTION";
        }
    }

    public string to_string() {
        switch (this) {
            case ROLLBACK:
                return "rollback";

            case COMMIT:
                return "commit";

            default:
                return "(unknown: %d)".printf(this);
        }
    }
}

