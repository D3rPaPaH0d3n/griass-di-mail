/*
 * Copyright 2026 Software Freedom Conservancy Inc.
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

internal class Geary.Graph.SearchQuery : Geary.SearchQuery {

    public SearchQuery(Gee.List<Geary.SearchQuery.Term> expression, string text) {
        base(expression, text);
    }

}
