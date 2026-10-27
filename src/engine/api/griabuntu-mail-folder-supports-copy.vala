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
 * The addition of the GriabuntuMail.FolderSupport.Copy interface to a {@link
 * GriabuntuMail.Folder} indicates it supports a copy email operation.
 *
 * A copied email will not be removed from the current folder but will
 * appear in the destination.
 *
 * Copy does not imply {@link GriabuntuMail.FolderSupport.Move}, or
 * vice-versa.
 */
public interface GriabuntuMail.FolderSupport.Copy : Folder {

    /**
     * Copies messages into another folder.
     *
     * If the destination is this {@link Folder}, the operation will
     * not make a copy of the message but will return success.
     *
     * This folder must be opened prior to attempting this operation.
     */
    public abstract async void
        copy_email_async(Gee.Collection<EmailIdentifier> to_copy,
                         FolderPath destination,
                         GLib.Cancellable? cancellable = null)
        throws GLib.Error;

}
