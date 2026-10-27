/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

private class GriabuntuMail.Outbox.FolderProperties : GriabuntuMail.FolderProperties {

    public FolderProperties(int total, int unread) {
        base(
            total, unread,
            Trillian.FALSE, Trillian.FALSE, Trillian.TRUE,
            true, false, false
        );
    }

    public void set_total(int total) {
        this.email_total = total;
    }

}
