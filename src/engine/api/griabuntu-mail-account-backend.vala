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
 * Specifies the protocol backend used to access an account.
 */
public enum GriabuntuMail.AccountBackend {
    IMAP_SMTP,
    MICROSOFT_GRAPH;
}
