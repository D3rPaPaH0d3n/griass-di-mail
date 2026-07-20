/*
 * Copyright 2026 Daniel Elia <d.elia@outlook.com>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

internal class Convey.Graph.SearchQuery : Convey.SearchQuery {

    public SearchQuery(Gee.List<Convey.SearchQuery.Term> expression, string text) {
        base(expression, text);
    }

}
