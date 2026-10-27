/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * A representation of the types of data to be found in a STATUS response.
 *
 * See [[http://tools.ietf.org/html/rfc3501#section-7.2.4]]
 *
 * @see StatusData
 */
public enum GriabuntuMail.Imap.StatusDataType {
    MESSAGES,
    RECENT,
    UIDNEXT,
    UIDVALIDITY,
    UNSEEN;

    public static StatusDataType[] all() {
        return { MESSAGES, RECENT, UIDNEXT, UIDVALIDITY, UNSEEN };
    }

    public string to_string() {
        switch (this) {
            case MESSAGES:
                return "MESSAGES";

            case RECENT:
                return "RECENT";

            case UIDNEXT:
                return "UIDNEXT";

            case UIDVALIDITY:
                return "UIDVALIDITY";

            case UNSEEN:
                return "UNSEEN";

            default:
                assert_not_reached();
        }
    }

    public static StatusDataType from_parameter(StringParameter stringp) throws ImapError {
        switch (stringp.as_lower()) {
            case "messages":
                return MESSAGES;

            case "recent":
                return RECENT;

            case "uidnext":
                return UIDNEXT;

            case "uidvalidity":
                return UIDVALIDITY;

            case "unseen":
                return UNSEEN;

            default:
                throw new ImapError.PARSE_ERROR("Unknown status data type \"%s\"", stringp.to_string());
        }
    }

    public StringParameter to_parameter() {
        return new AtomParameter(to_string());
    }
}

