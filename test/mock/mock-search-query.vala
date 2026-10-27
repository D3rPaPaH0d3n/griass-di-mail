/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright © 2017-2020 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

public class Mock.SearchQuery : GriabuntuMail.SearchQuery {

    internal SearchQuery(Gee.List<GriabuntuMail.SearchQuery.Term> expression,
                         string raw) {
        base(expression, raw);
    }

}
