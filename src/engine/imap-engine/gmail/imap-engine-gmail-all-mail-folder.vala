/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * Gmail's All Mail folder supports basic operations as well as true removal of emails.
 */

private class Convey.ImapEngine.GmailAllMailFolder : MinimalFolder, FolderSupport.Remove {
    public GmailAllMailFolder(GmailAccount account,
                              ImapDB.Folder local_folder) {
        base(account, local_folder, ALL_MAIL);
    }

    public async void
        remove_email_async(Gee.Collection<Convey.EmailIdentifier> email_ids,
                           GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        yield GmailFolder.true_remove_email_async(this, email_ids, cancellable);
    }
}
