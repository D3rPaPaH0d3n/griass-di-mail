/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

public errordomain Convey.NonblockingError {
    /**
     * Indicates a call was made when it shouldn't have been; that the primitive was in such a
     * state that it cannot properly respond or account for the requested change.
     */
    INVALID
}

