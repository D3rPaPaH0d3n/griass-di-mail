/*
 * Copyright 2026 Software Freedom Conservancy Inc.
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

internal class Geary.Graph.FolderProperties : Geary.FolderProperties {

    public FolderProperties(int total, int unread) {
        base(
            total,
            unread,
            Geary.Trillian.FALSE,
            Geary.Trillian.FALSE,
            Geary.Trillian.TRUE,
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
