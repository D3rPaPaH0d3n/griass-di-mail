/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 *Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * The addition of the GriabuntuMail.FolderSupport.Move interface indicates
 * that the {@link GriabuntuMail.Folder} supports a move email operation.
 * Moved messages are removed from this Folder.
 *
 * Move does not imply {@link GriabuntuMail.FolderSupport.Copy}, or
 * vice-versa.
 */
public interface GriabuntuMail.FolderSupport.Move : Folder {

    /**
     * Moves messages to another folder.
     *
     * If the destination is this {@link Folder}, the operation will
     * not move the message in any way but will return success.
     *
     * This folder must be opened prior to attempting this operation.
     *
     * @return A {@link GriabuntuMail.Revokable} that may be used to revoke
     * (undo) this operation later.
     */
    public abstract async Revokable?
        move_email_async(Gee.Collection<EmailIdentifier> to_move,
                         FolderPath destination,
                         GLib.Cancellable? cancellable = null)
        throws GLib.Error;

}
