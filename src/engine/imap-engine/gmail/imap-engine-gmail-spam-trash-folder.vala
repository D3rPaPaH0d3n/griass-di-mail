/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * Gmail's Spam and Trash folders support basic operations and
 * removing messages with a traditional IMAP STORE/EXPUNGE operation.
 */
private class GriabuntuMail.ImapEngine.GmailSpamTrashFolder :
    MinimalFolder,
    FolderSupport.Remove,
    FolderSupport.Empty {

    public GmailSpamTrashFolder(GmailAccount account,
                                ImapDB.Folder local_folder,
                                Folder.SpecialUse use) {
        base(account, local_folder, use);
    }

    public async void
        remove_email_async(Gee.Collection<GriabuntuMail.EmailIdentifier> email_ids,
                           GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        yield expunge_email_async(email_ids, cancellable);
    }

    public async void empty_folder_async(Cancellable? cancellable = null)
        throws Error {
        yield expunge_all_async(cancellable);
    }

}
