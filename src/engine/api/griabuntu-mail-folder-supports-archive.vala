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
 * The addition of this interface to {@link GriabuntuMail.Folder} indicates
 * that it supports an archive operation (which may or may not be in
 * addition to a remove operation via {@link
 * GriabuntuMail.FolderSupport.Remove}).
 *
 * An archive operation acts like remove except that the mail is still
 * available on the server, usually in an All Mail folder and perhaps
 * others.  It does not imply that the mail message was moved to the
 * Trash folder.
 */
public interface GriabuntuMail.FolderSupport.Archive : Folder {

    /**
     * Archives the specified emails from the folder.
     *
     * This folder must be opened prior to attempting this operation.
     *
     * @return A {@link GriabuntuMail.Revokable} that may be used to revoke
     * (undo) this operation later.
     */
    public abstract async Revokable?
        archive_email_async(Gee.Collection<EmailIdentifier> email_ids,
                            GLib.Cancellable? cancellable = null)
        throws GLib.Error;

}
