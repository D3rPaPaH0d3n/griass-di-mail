/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * Utility methods for manipulating and examining data particular to MIME.
 */

namespace GriabuntuMail.Mime.DataFormat {

private const char[] CONTENT_TYPE_TOKEN_SPECIALS = {
    '(', ')', '<', '>', '@', ',', ';', ':', '\\', '"', '/', '[', ']', '?', '='
};

public enum Encoding {
    QUOTING_REQUIRED,
    QUOTING_OPTIONAL,
    UNALLOWED
}

public Encoding get_encoding_requirement(string str) {
    if (String.is_empty(str))
        return Encoding.QUOTING_REQUIRED;

    Encoding encoding = Encoding.QUOTING_OPTIONAL;
    int index = 0;
    for (;;) {
        char ch = str[index++];
        if (ch == String.EOS)
            break;

        if (ch.iscntrl())
            return Encoding.UNALLOWED;

        // don't return immediately, it's possible unallowed characters may still be ahead
        if (ch.isspace() || ch in CONTENT_TYPE_TOKEN_SPECIALS)
            encoding = Encoding.QUOTING_REQUIRED;
    }

    return encoding;
}

}
