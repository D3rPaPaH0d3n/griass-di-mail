/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright © 2017-2020 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

public class Mock.Account : GriabuntuMail.Account,
    ValaUnit.TestAssertions,
    ValaUnit.MockObject {


    protected Gee.Queue<ValaUnit.ExpectedCall> expected {
        get; set; default = new Gee.LinkedList<ValaUnit.ExpectedCall>();
    }


    public Account(GriabuntuMail.AccountInformation config) {
        base(config,
             new ClientService(
                 config,
                 config.incoming,
                 new GriabuntuMail.Endpoint(
                     new GLib.NetworkAddress(
                         config.incoming.host, config.incoming.port
                     ),
                     0, 0
                 )
             ),
             new ClientService(
                 config,
                 config.outgoing,
                 new GriabuntuMail.Endpoint(
                     new GLib.NetworkAddress(
                         config.outgoing.host, config.outgoing.port
                     ),
                     0, 0
                 )
             )
        );
        this.contact_store = new ContactStore();
    }

    public override async void open_async(GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        void_call("open_async", { cancellable });
    }

    public override async void close_async(GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        void_call("close_async", { cancellable });
    }

    public override bool is_open() {
        try {
            return boolean_call("is_open", {}, false);
        } catch (GLib.Error err) {
            return false;
        }
    }

    public override void cancel_remote_update() {
        try {
            void_call("cancel_remote_update", {});
        } catch (GLib.Error err) {
        }
    }

    public override async void rebuild_async(GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        void_call("rebuild_async", { cancellable });
    }

    public override Gee.Collection<GriabuntuMail.Folder>
        list_matching_folders(GriabuntuMail.FolderPath? parent) {
        try {
            return object_call<Gee.Collection<GriabuntuMail.Folder>>(
                "get_containing_folders_async",
                {parent},
                Gee.List.empty<GriabuntuMail.Folder>()
            );
        } catch (GLib.Error err) {
            return Gee.Collection.empty<GriabuntuMail.Folder>();
        }
    }

    public override async GriabuntuMail.Folder create_personal_folder(
        string name,
        GriabuntuMail.Folder.SpecialUse use = NONE,
        GLib.Cancellable? cancellable = null,
        GriabuntuMail.Folder? parent = null
    ) throws GLib.Error {
        return object_call<Folder>(
            "create_personal_folder",
            { box_arg(name), box_arg(use), cancellable },
            new Folder(null, null, null, use, null)
        );
    }

    public override async void delete_folder(
        GriabuntuMail.Folder folder,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        void_call("delete_folder", { folder, cancellable });
    }

    public override async GriabuntuMail.Folder rename_folder(
        GriabuntuMail.Folder folder,
        string new_name,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        return object_call<Folder>(
            "rename_folder",
            { folder, box_arg(new_name), cancellable },
            new Folder(null, null, null, NONE, null)
        );
    }

    /** {@inheritDoc} */
    public override void register_local_folder(GriabuntuMail.Folder local)
        throws GLib.Error {
        void_call("register_local_folder", { local });
    }

    /** {@inheritDoc} */
    public override void deregister_local_folder(GriabuntuMail.Folder local)
        throws GLib.Error {
        void_call("deregister_local_folder", { local });
    }

    public override GriabuntuMail.EmailIdentifier to_email_identifier(GLib.Variant serialised)
        throws GriabuntuMail.EngineError.BAD_PARAMETERS {
        try {
            return object_or_throw_call<GriabuntuMail.EmailIdentifier>(
                "to_email_identifier",
                { box_arg(serialised) },
                new GriabuntuMail.EngineError.BAD_PARAMETERS("Mock error")
            );
        } catch (GriabuntuMail.EngineError.BAD_PARAMETERS err) {
            throw err;
        } catch (GLib.Error err) {
            return new EmailIdentifer(0);
        }
    }

    public override GriabuntuMail.FolderPath to_folder_path(GLib.Variant serialised)
        throws GriabuntuMail.EngineError.BAD_PARAMETERS {
        try {
            return object_or_throw_call<GriabuntuMail.FolderPath>(
                "to_folder_path",
                { box_arg(serialised) },
                new GriabuntuMail.EngineError.BAD_PARAMETERS("Mock error")
            );
        } catch (GriabuntuMail.EngineError.BAD_PARAMETERS err) {
            throw err;
        } catch (GLib.Error err) {
            return new GriabuntuMail.FolderRoot("#mock", false);
        }
    }

    public override GriabuntuMail.Folder get_folder(GriabuntuMail.FolderPath path)
        throws GriabuntuMail.EngineError.NOT_FOUND {
        try {
            return object_or_throw_call<Folder>(
                "get_folder",
                { path },
                new GriabuntuMail.EngineError.NOT_FOUND("Mock error")
            );
        } catch (GriabuntuMail.EngineError.NOT_FOUND err) {
            throw err;
        } catch (GLib.Error err) {
            return new Folder(null, null, null, NONE, null);
        }
    }

    public override Gee.Collection<GriabuntuMail.Folder> list_folders() {
        try {
            return object_call<Gee.Collection<GriabuntuMail.Folder>>(
                "list_folders", {}, Gee.List.empty<GriabuntuMail.Folder>()
            );
        } catch (GLib.Error err) {
            return Gee.List.empty<GriabuntuMail.Folder>();
        }
    }

    public override GriabuntuMail.Folder? get_special_folder(GriabuntuMail.Folder.SpecialUse special) {
        try {
            return object_call<GriabuntuMail.Folder?>(
                "get_special_folder", {box_arg(special)}, null
            );
        } catch (GLib.Error err) {
            return null;
        }
    }

    public override async GriabuntuMail.Folder
        get_required_special_folder_async(GriabuntuMail.Folder.SpecialUse special,
                                          GLib.Cancellable? cancellable = null)
    throws GLib.Error {
        return object_or_throw_call<GriabuntuMail.Folder>(
            "get_required_special_folder_async",
            { box_arg(special), cancellable },
            new GriabuntuMail.EngineError.NOT_FOUND("Mock call")
        );
    }

    public override async Gee.MultiMap<GriabuntuMail.Email,GriabuntuMail.FolderPath?>?
        local_search_message_id_async(GriabuntuMail.RFC822.MessageID message_id,
                                      GriabuntuMail.Email.Field requested_fields,
                                      bool partial_ok,
                                      Gee.Collection<GriabuntuMail.FolderPath?>? folder_blacklist,
                                      GriabuntuMail.EmailFlags? flag_blacklist,
                                      GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        return object_call<Gee.MultiMap<GriabuntuMail.Email,GriabuntuMail.FolderPath?>?>(
            "local_search_message_id_async",
            {
                message_id,
                box_arg(requested_fields),
                box_arg(partial_ok),
                folder_blacklist,
                flag_blacklist,
                cancellable
            },
            null
        );
    }

    public override async Gee.List<GriabuntuMail.Email> list_local_email_async(
        Gee.Collection<GriabuntuMail.EmailIdentifier> ids,
        GriabuntuMail.Email.Field required_fields,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        return object_or_throw_call<Gee.List<GriabuntuMail.Email>>(
            "list_local_email_async",
            {ids, box_arg(required_fields), cancellable},
            new GriabuntuMail.EngineError.NOT_FOUND("Mock call")
        );
    }

    public override async GriabuntuMail.Email
        local_fetch_email_async(GriabuntuMail.EmailIdentifier email_id,
                                GriabuntuMail.Email.Field required_fields,
                                GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        return object_or_throw_call<GriabuntuMail.Email>(
            "local_fetch_email_async",
            {email_id, box_arg(required_fields), cancellable},
            new GriabuntuMail.EngineError.NOT_FOUND("Mock call")
        );
    }

    public override GriabuntuMail.SearchQuery new_search_query(
        Gee.List<GriabuntuMail.SearchQuery.Term> expression,
        string text
    ) throws GLib.Error {
        return new SearchQuery(expression, text);
    }

    public override async Gee.Collection<GriabuntuMail.EmailIdentifier>?
        local_search_async(GriabuntuMail.SearchQuery query,
                           int limit = 100,
                           int offset = 0,
                           Gee.Collection<GriabuntuMail.FolderPath?>? folder_blacklist = null,
                           Gee.Collection<GriabuntuMail.EmailIdentifier>? search_ids = null,
                           GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        return object_call<Gee.Collection<GriabuntuMail.EmailIdentifier>?>(
            "local_search_async",
            {
                query,
                box_arg(limit),
                box_arg(offset),
                folder_blacklist,
                search_ids,
                cancellable
            },
            null
        );
    }

    public override async Gee.Set<string>?
        get_search_matches_async(GriabuntuMail.SearchQuery query,
                                 Gee.Collection<GriabuntuMail.EmailIdentifier> ids,
                                 GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        return object_call<Gee.Set<string>?>(
            "get_search_matches_async", {query, ids, cancellable}, null
        );
    }

    public override async Gee.MultiMap<GriabuntuMail.EmailIdentifier,GriabuntuMail.FolderPath>?
        get_containing_folders_async(Gee.Collection<GriabuntuMail.EmailIdentifier> ids,
                                     GLib.Cancellable? cancellable)
        throws GLib.Error {
        return object_call<Gee.MultiMap<GriabuntuMail.EmailIdentifier, GriabuntuMail.FolderPath>?>(
            "get_containing_folders_async", {ids, cancellable}, null
        );
    }

    public override async void cleanup_storage(GLib.Cancellable? cancellable) {
        try {
            void_call("cleanup_storage", {cancellable});
        } catch (GLib.Error err) {
            // fine
        }
    }

}
