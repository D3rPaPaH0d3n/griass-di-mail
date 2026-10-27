/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */


/**
 * Thrown when an error occurs communicating with a SMTP server.
 */
public errordomain GriabuntuMail.SmtpError {

    /** The client already has a connection to the server. */
    ALREADY_CONNECTED,

    /** The credentials presented for authentication were rejected. */
    AUTHENTICATION_FAILED,

    /** The client does not have a connection to the server. */
    NOT_CONNECTED,

    /** The server does not support an SMTP feature required by the engine. */
    NOT_SUPPORTED,

    /** A response from the server could not be parsed. */
    PARSE_ERROR,

    /** A message could not be sent because a field required by SMTP was missing. */
    REQUIRED_FIELD,

    /** The server reported an error. */
    SERVER_ERROR,

    /** Establishing STARTTLS  was attempted, but failed. */
    STARTTLS_FAILED
}
