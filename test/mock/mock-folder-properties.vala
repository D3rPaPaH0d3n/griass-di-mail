/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2019 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

public class Mock.FolderPoperties : GriabuntuMail.FolderProperties {


    public FolderPoperties() {
        base(
            0,
            0,
            GriabuntuMail.Trillian.UNKNOWN,
            GriabuntuMail.Trillian.UNKNOWN,
            GriabuntuMail.Trillian.UNKNOWN,
            false,
            false,
            false
        );
    }

}
