/*
 * Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

private class Convey.ImapEngine.GenericFolder : MinimalFolder,
    Convey.FolderSupport.Archive,
    Convey.FolderSupport.Remove,
    Convey.FolderSupport.Create,
    Convey.FolderSupport.Empty {

    public GenericFolder(GenericAccount account,
                         ImapDB.Folder local_folder,
                         Folder.SpecialUse use) {
        base (account, local_folder, use);
    }

    public async Convey.Revokable?
        archive_email_async(Gee.Collection<Convey.EmailIdentifier> email_ids,
                            GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        Convey.Folder? archive_folder = null;
        try {
            archive_folder = yield account.get_required_special_folder_async(
                Folder.SpecialUse.ARCHIVE, cancellable
            );
        } catch (Error e) {
            debug("Error looking up archive folder in %s: %s", account.to_string(), e.message);
        }

        if (archive_folder == null) {
            debug("Can't archive email because no archive folder was found in %s", account.to_string());
        } else {
            return yield move_email_async(email_ids, archive_folder.path, cancellable);
        }

        return null;
    }

    public async void
        remove_email_async(Gee.Collection<Convey.EmailIdentifier> email_ids,
                           GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        yield expunge_email_async(email_ids, cancellable);
    }

    public async void empty_folder_async(Cancellable? cancellable = null) throws Error {
        yield expunge_all_async(cancellable);
    }

    public new async EmailIdentifier?
        create_email_async(RFC822.Message rfc822,
                           EmailFlags? flags,
                           DateTime? date_received,
                           GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        return yield base.create_email_async(
            rfc822, flags, date_received, cancellable
        );
    }
}
