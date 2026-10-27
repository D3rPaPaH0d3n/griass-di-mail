/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * An optional status code accompanying a {@link ServerResponse}.
 *
 * See [[http://tools.ietf.org/html/rfc3501#section-7.1]] for more information.
 */

public enum GriabuntuMail.Imap.Status {
    OK,
    NO,
    BAD,
    PREAUTH,
    BYE;

    public string to_string() {
        switch (this) {
            case OK:
                return "ok";

            case NO:
                return "no";

            case BAD:
                return "bad";

            case PREAUTH:
                return "preauth";

            case BYE:
                return "bye";

            default:
                assert_not_reached();
        }
    }

    public static Status from_parameter(StringParameter strparam) throws ImapError {
        switch (strparam.as_lower()) {
            case "ok":
                return OK;

            case "no":
                return NO;

            case "bad":
                return BAD;

            case "preauth":
                return PREAUTH;

            case "bye":
                return BYE;

            default:
                throw new ImapError.PARSE_ERROR("Unrecognized status response \"%s\"", strparam.to_string());
        }
    }

    public Parameter to_parameter() {
        return new AtomParameter(to_string());
    }
}

