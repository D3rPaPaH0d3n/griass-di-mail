/*
 * Copyright 2026 Daniel Elia <d.elia@outlook.com>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

internal class Convey.Graph.SearchQuery : Convey.SearchQuery {

    public SearchQuery(Gee.List<Convey.SearchQuery.Term> expression, string text) {
        base(expression, text);
    }

}
