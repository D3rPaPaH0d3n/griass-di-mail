/*
 * Copyright 2026 Daniel Elia <d.elia@outlook.com>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

/**
 * Errors thrown by {@link Convey.Graph.Client} for non-2xx HTTP responses.
 *
 * Lets callers branch on the actual status class instead of parsing the
 * error message string.
 */
public errordomain Convey.Graph.HttpError {
    BAD_REQUEST,
    UNAUTHORIZED,
    NOT_FOUND,
    GONE,
    TOO_MANY_REQUESTS,
    SERVER;
}
