/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

public enum GriabuntuMail.Db.TransactionType {
    DEFERRED,
    IMMEDIATE,
    EXCLUSIVE,

    // coarse synonyms
    RO = DEFERRED,
    RW = IMMEDIATE,
    WR = EXCLUSIVE,
    WO = EXCLUSIVE;

    public unowned string sql() {
        switch (this) {
            case IMMEDIATE:
                return "BEGIN IMMEDIATE";

            case EXCLUSIVE:
                return "BEGIN EXCLUSIVE";

            case DEFERRED:
            default:
                return "BEGIN DEFERRED";
        }
    }

    public string to_string() {
        switch (this) {
            case DEFERRED:
                return "DEFERRED";

            case IMMEDIATE:
                return "IMMEDIATE";

            case EXCLUSIVE:
                return "EXCLUSIVE";

            default:
                return "(unknown: %d)".printf(this);
        }
    }
}

