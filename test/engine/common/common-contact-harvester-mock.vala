/*
 * Copyright 2019 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

internal class Convey.MockContactHarvester :
    Convey.BaseObject,
    ContactHarvester {

    public async void harvest_from_email(Gee.Collection<Email> messages,
                                         GLib.Cancellable? cancellable)
        throws GLib.Error {
    }

}
