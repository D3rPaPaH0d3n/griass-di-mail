/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2026 Daniel Elia <d.elia@outlook.com>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * Errors thrown by {@link GriabuntuMail.Graph.Client} for non-2xx HTTP responses.
 *
 * Lets callers branch on the actual status class instead of parsing the
 * error message string.
 */
public errordomain GriabuntuMail.Graph.HttpError {
    BAD_REQUEST,
    UNAUTHORIZED,
    NOT_FOUND,
    GONE,
    TOO_MANY_REQUESTS,
    SERVER;
}
