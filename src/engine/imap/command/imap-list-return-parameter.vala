/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * RETURN parameters for {@link ListCommand}.
 *
 * LIST's extended syntax allows for special RETURN parameters to be included indicating additional
 * information for the server to return as part of the LIST results.  ListReturnParameters allows
 * for the well-known parameters to be easily generated and added to ListCommand.
 *
 * See the LIST-STATUS ([[https://tools.ietf.org/html/rfc5819]]) and SPECIAL-USE
 * ([[https://tools.ietf.org/html/rfc6154]]) RFCs for examples of this in use.
 */

public class Convey.Imap.ListReturnParameter : ListParameter {
    /**
     * See [[https://tools.ietf.org/html/rfc6154]]
     */
    public const string SPECIAL_USE = "special-use";

    /**
     * Creates an empty {@link ListReturnParameter}.
     *
     * If passed in without additions, this will be ignored by {@link ListCommand}.
     */
    public ListReturnParameter() {
    }

    public void add_special_use() {
        add(StringParameter.get_best_for_unchecked(SPECIAL_USE));
    }
}

