/*
 * Copyright 2026 Daniel Elia <d.elia@outlook.com>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
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
