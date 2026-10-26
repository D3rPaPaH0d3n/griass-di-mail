/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

public class Convey.Smtp.Capabilities : Convey.GenericCapabilities {

    public const string STARTTLS = "starttls";
    public const string AUTH = "auth";

    public const string AUTH_PLAIN = "plain";
    public const string AUTH_LOGIN = "login";
    public const string AUTH_OAUTH2 = "xoauth2";
    public const string 8BITMIME = "8bitmime";

    public const string NAME_SEPARATOR = " ";
    public const string VALUE_SEPARATOR = " ";

    public Capabilities() {
        base (NAME_SEPARATOR, VALUE_SEPARATOR);
    }

    /**
     * Returns number of response lines added.
     */
    public int add_ehlo_response(Response response) {
        // First line in response is server information, not capabilities
        int count = 0;
        for (int ctr = 1; ctr < response.lines.size; ctr++) {
            if (add_response_line(response.lines[ctr]))
                count++;
        }

        return count;
    }

    public bool add_response_line(ResponseLine line) {
        return !String.is_empty(line.explanation) ? parse_and_add_capability(line.explanation) : false;
    }
}

