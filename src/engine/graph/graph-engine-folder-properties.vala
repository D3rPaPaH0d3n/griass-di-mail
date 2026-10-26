/*
 * Copyright 2026 Daniel Elia <d.elia@outlook.com>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

internal class Convey.Graph.FolderProperties : Convey.FolderProperties {

    public FolderProperties(int total, int unread) {
        base(
            total,
            unread,
            Convey.Trillian.FALSE,
            Convey.Trillian.FALSE,
            Convey.Trillian.TRUE,
            false,
            false,
            false
        );
    }

    public void set_total(int total) {
        this.email_total = total;
    }

    public void set_unread(int unread) {
        this.email_unread = unread;
    }

}
