/*
 * Copyright 2019 Michael Gratton <mike@vee.net>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

internal class Mock.ContactStore : GLib.Object,
    Convey.ContactStore, ValaUnit.TestAssertions, ValaUnit.MockObject {

    protected Gee.Queue<ValaUnit.ExpectedCall> expected {
        get; set; default = new Gee.LinkedList<ValaUnit.ExpectedCall>();
    }

    public async Convey.Contact? get_by_rfc822(Convey.RFC822.MailboxAddress address,
                                              GLib.Cancellable? cancellable)
        throws GLib.Error {
        return object_call<Convey.Contact?>(
            "get_by_rfc822", { address, cancellable }, null
        );
    }

    public async Gee.Collection<Convey.Contact> search(string query,
                                                      uint min_importance,
                                                      uint limit,
                                                      GLib.Cancellable? cancellable)
        throws GLib.Error {
        return object_call<Gee.Collection<Convey.Contact>>(
            "search",
            {
                box_arg(query),
                uint_arg(min_importance),
                uint_arg(limit),
                cancellable
            },
            Gee.Collection.empty<Convey.Contact>()
        );
    }

    public async void update_contacts(Gee.Collection<Convey.Contact> updated,
                                      GLib.Cancellable? cancellable)
        throws GLib.Error {
        void_call("update_contacts", { updated, cancellable });
    }

}
