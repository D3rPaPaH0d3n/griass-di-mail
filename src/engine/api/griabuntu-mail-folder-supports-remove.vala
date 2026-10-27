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
 * The addition of the GriabuntuMail.FolderSupport.Remove interface to a
 * {@link GriabuntuMail.Folder} indicates that it supports removing (deleting)
 * email.
 *
 * This generally means that the message is deleted from the server
 * and is not recoverable.  It _may_ mean the message is moved to a
 * Trash folder where it may or may not be automatically deleted some
 * time later; this behavior is server-specific and not always
 * determinable by Griabuntu Mail (or worked around, either).
 *
 * The remove operation is distinct from the archive operation,
 * available via {@link GriabuntuMail.FolderSupport.Archive}.
 *
 * A Folder that does not support Remove does not imply that email
 * might not be removed later, such as by the server.
 */
public interface GriabuntuMail.FolderSupport.Remove : Folder {

    /**
     * Removes the specified emails from the folder.
     *
     * This folder must be opened prior to attempting this operation.
     */
    public abstract async void
        remove_email_async(Gee.Collection<EmailIdentifier> email_ids,
                           GLib.Cancellable? cancellable = null)
        throws GLib.Error;

}
