/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2019 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

internal class Mock.ContactStore : GLib.Object,
    GriabuntuMail.ContactStore, ValaUnit.TestAssertions, ValaUnit.MockObject {

    protected Gee.Queue<ValaUnit.ExpectedCall> expected {
        get; set; default = new Gee.LinkedList<ValaUnit.ExpectedCall>();
    }

    public async GriabuntuMail.Contact? get_by_rfc822(GriabuntuMail.RFC822.MailboxAddress address,
                                              GLib.Cancellable? cancellable)
        throws GLib.Error {
        return object_call<GriabuntuMail.Contact?>(
            "get_by_rfc822", { address, cancellable }, null
        );
    }

    public async Gee.Collection<GriabuntuMail.Contact> search(string query,
                                                      uint min_importance,
                                                      uint limit,
                                                      GLib.Cancellable? cancellable)
        throws GLib.Error {
        return object_call<Gee.Collection<GriabuntuMail.Contact>>(
            "search",
            {
                box_arg(query),
                uint_arg(min_importance),
                uint_arg(limit),
                cancellable
            },
            Gee.Collection.empty<GriabuntuMail.Contact>()
        );
    }

    public async void update_contacts(Gee.Collection<GriabuntuMail.Contact> updated,
                                      GLib.Cancellable? cancellable)
        throws GLib.Error {
        void_call("update_contacts", { updated, cancellable });
    }

}
