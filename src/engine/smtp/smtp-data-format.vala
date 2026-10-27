/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

namespace GriabuntuMail.Smtp.DataFormat {

public const string ARG_SEPARATOR = " ";

public const string LINE_TERMINATOR = "\r\n";
public const DataStreamNewlineType LINE_TERMINATOR_TYPE = DataStreamNewlineType.CR_LF;

public const string DATA_TERMINATOR = "\r\n.\r\n";

public const string CANCEL_AUTHENTICATION = "*";

}

