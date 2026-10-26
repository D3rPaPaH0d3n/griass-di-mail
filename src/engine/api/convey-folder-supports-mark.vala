/*
 * Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * The addition of the Convey.FolderSupport.Mark interface indicates
 * the {@link Convey.Folder} supports marking and unmarking messages
 * with system and user-defined flags.
 */
public interface Convey.FolderSupport.Mark : Convey.Folder {

    /**
     * Adds and removes flags from a list of messages.
     *
     * This folder must be opened prior to attempting this operation.
     */
    public abstract async void
        mark_email_async(Gee.Collection<EmailIdentifier> to_mark,
                         EmailFlags? flags_to_add,
                         EmailFlags? flags_to_remove,
                         GLib.Cancellable? cancellable = null)
        throws GLib.Error;

}
