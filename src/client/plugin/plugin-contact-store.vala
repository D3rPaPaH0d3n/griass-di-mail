/*
 * Copyright © 2020 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * Provides plugins with access to contact information.
 *
 * Plugins may obtain instances of this object from their context
 * objects, for example {@link
 * NotificationContext.get_contacts_for_folder}.
 */
public interface Plugin.ContactStore : Convey.BaseObject {


    /** Searches for contacts based on a specific string */
    public abstract async Gee.Collection<global::Application.Contact> search(
        string query,
        uint min_importance,
        uint limit,
        GLib.Cancellable? cancellable
    ) throws GLib.Error;


    /**
     * Returns a contact for a specific mailbox.
     *
     * Returns a contact that has the given mailbox address listed as
     * a primary or secondary email. A contact will always be
     * returned, so if no matching contact already exists a new,
     * non-persistent contact will be returned.
     */
    public abstract async global::Application.Contact load(
        Convey.RFC822.MailboxAddress mailbox,
        GLib.Cancellable? cancellable
    ) throws GLib.Error;


}
