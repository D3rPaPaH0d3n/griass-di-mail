/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2016 Software Freedom Conservancy Inc.
 * Copyright 2019 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * Interface for objects that provide contact information storage.
 *
 * Implementations of this class will typically be backed by a
 * database. As such, to avoid IO overhead, batch calls together using
 * collections of contacts wherever possible.
 */
public interface GriabuntuMail.ContactStore : GLib.Object {

    /** Returns the contact matching the given email address, if any */
    public abstract async Contact? get_by_rfc822(GriabuntuMail.RFC822.MailboxAddress address,
                                                 GLib.Cancellable? cancellable)
        throws GLib.Error;

    /** Searches for contacts based on a specific string */
    public abstract async Gee.Collection<Contact> search(string query,
                                                         uint min_importance,
                                                         uint limit,
                                                         GLib.Cancellable? cancellable)
        throws GLib.Error;

    /** Updates (or adds) a set of contacts in the underlying store */
    public abstract async void update_contacts(Gee.Collection<Contact> updated,
                                               GLib.Cancellable? cancellable)
        throws GLib.Error;

}
