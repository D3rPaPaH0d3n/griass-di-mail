/*
 * Copyright 2026 Software Freedom Conservancy Inc.
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

internal class Geary.Graph.Account : Geary.Account {

    private const string REMOTE_ROOT_LABEL = "$geary-graph";
    private const uint REFRESH_LOADED_FOLDERS_SEC = 15;

    private Geary.FolderRoot remote_folder_root =
        new Geary.FolderRoot(REMOTE_ROOT_LABEL, false);
    private Gee.TreeMap<Geary.FolderPath,Geary.Folder> remote_folders =
        new Gee.TreeMap<Geary.FolderPath,Geary.Folder>((a, b) => a.compare_to(b));
    private Gee.TreeMap<Geary.FolderPath,Geary.Folder> local_folders =
        new Gee.TreeMap<Geary.FolderPath,Geary.Folder>((a, b) => a.compare_to(b));
    private Gee.HashMap<Geary.Folder.SpecialUse,Geary.Graph.Folder> special_folders =
        new Gee.HashMap<Geary.Folder.SpecialUse,Geary.Graph.Folder>();

    private Geary.Graph.Client client;
    private Geary.TimeoutManager refresh_loaded_folders_timer;
    private bool is_account_open = false;
    private bool prefetch_refresh_running = false;
    private bool prefetch_refresh_pending = false;


    public Account(Geary.AccountInformation information,
                   Geary.Endpoint incoming_remote,
                   Geary.Endpoint outgoing_remote) {
        base(
            information,
            new Geary.Graph.Service(information, information.incoming, incoming_remote),
            new Geary.Graph.Service(information, information.outgoing, outgoing_remote)
        );
        this.contact_store = new Geary.Graph.NoopContactStore();
        this.background_progress = new Geary.ReentrantProgressMonitor(
            Geary.ProgressType.ACTIVITY
        );
        this.db_upgrade_monitor = new Geary.ReentrantProgressMonitor(
            Geary.ProgressType.ACTIVITY
        );
        this.db_vacuum_monitor = new Geary.ReentrantProgressMonitor(
            Geary.ProgressType.ACTIVITY
        );
        this.client = new Geary.Graph.Client(information);
        this.refresh_loaded_folders_timer = new Geary.TimeoutManager.seconds(
            REFRESH_LOADED_FOLDERS_SEC,
            () => { queue_prefetch_refresh(); }
        );
        this.refresh_loaded_folders_timer.repetition = Geary.TimeoutManager.Repeat.FOREVER;
        this.information.notify["prefetch-period-days"].connect((obj, pspec) => {
            queue_prefetch_refresh();
        });

        add_folder("Inbox", "inbox", Geary.Folder.SpecialUse.INBOX);
        add_folder("Sent", "sentitems", Geary.Folder.SpecialUse.SENT);
        add_folder("Drafts", "drafts", Geary.Folder.SpecialUse.DRAFTS);
        add_folder("Trash", "deleteditems", Geary.Folder.SpecialUse.TRASH);
        add_folder("Junk", "junkemail", Geary.Folder.SpecialUse.JUNK);
        add_folder("Archive", "archive", Geary.Folder.SpecialUse.ARCHIVE);
    }

    public override async void open_async(GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        if (this.is_account_open) {
            return;
        }

        yield this.incoming.start(cancellable);
        yield this.outgoing.start(cancellable);

        this.is_account_open = true;
        notify_folders_available_unavailable(
            sort_by_path(this.remote_folders.values),
            null
        );
        notify_opened();
        Geary.Graph.Folder? inbox =
            this.get_graph_special_folder(Geary.Folder.SpecialUse.INBOX);
        if (inbox != null) {
            inbox.load_persisted_cache();
        }
        queue_prefetch_refresh();
        this.refresh_loaded_folders_timer.start();
    }

    public override async void close_async(GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        if (!this.is_account_open) {
            return;
        }
        this.refresh_loaded_folders_timer.reset();

        foreach (Geary.Folder folder in list_folders()) {
            if (folder.get_open_state() != Geary.Folder.OpenState.CLOSED) {
                yield folder.close_async(cancellable);
            }
        }

        notify_folders_available_unavailable(
            null,
            sort_by_path(list_folders())
        );

        yield this.outgoing.stop(cancellable);
        yield this.incoming.stop(cancellable);

        this.is_account_open = false;
        notify_closed();
    }

    public override bool is_open() {
        return this.is_account_open;
    }

    public override void cancel_remote_update() {
        this.prefetch_refresh_pending = false;
        queue_prefetch_refresh();
    }

    public override async void rebuild_async(GLib.Cancellable? cancellable = null)
        throws GLib.Error {
    }

    public override Geary.EmailIdentifier to_email_identifier(GLib.Variant serialised)
        throws Geary.EngineError.BAD_PARAMETERS {
        return new Geary.Graph.EmailIdentifier.from_variant(serialised);
    }

    public override Geary.FolderPath to_folder_path(GLib.Variant serialised)
        throws Geary.EngineError.BAD_PARAMETERS {
        string root = serialised.get_child_value(0).get_string();
        if (root == this.local_folder_root.label) {
            return this.local_folder_root.from_variant(serialised);
        }
        if (root == this.remote_folder_root.label) {
            return this.remote_folder_root.from_variant(serialised);
        }
        throw new Geary.EngineError.BAD_PARAMETERS(
            "Invalid serialised folder root label: %s", root
        );
    }

    public override Geary.Folder get_folder(Geary.FolderPath path)
        throws Geary.EngineError.NOT_FOUND {
        Geary.Folder? folder = this.remote_folders.get(path);
        if (folder == null) {
            folder = this.local_folders.get(path);
        }
        if (folder == null) {
            throw new Geary.EngineError.NOT_FOUND(
                "Unknown folder: %s", path.to_string()
            );
        }
        return folder;
    }

    public override Gee.Collection<Geary.Folder> list_folders() {
        Gee.ArrayList<Geary.Folder> folders = new Gee.ArrayList<Geary.Folder>();
        folders.add_all(this.remote_folders.values);
        folders.add_all(this.local_folders.values);
        return folders.read_only_view;
    }

    public override Gee.Collection<Geary.Folder> list_matching_folders(Geary.FolderPath? parent)
        throws Geary.EngineError.NOT_FOUND {
        if (parent == null) {
            return list_folders();
        }
        if (!this.remote_folders.has_key(parent) && !this.local_folders.has_key(parent)) {
            throw new Geary.EngineError.NOT_FOUND(
                "Unknown parent folder: %s", parent.to_string()
            );
        }
        Gee.ArrayList<Geary.Folder> matched = new Gee.ArrayList<Geary.Folder>();
        foreach (Geary.Folder folder in list_folders()) {
            if (folder.path != parent && folder.path.is_descendant(parent)) {
                matched.add(folder);
            }
        }
        return matched.read_only_view;
    }

    public override async Geary.Folder get_required_special_folder_async(
        Geary.Folder.SpecialUse special,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        Geary.Graph.Folder? folder = this.special_folders.get(special);
        if (folder == null) {
            throw new Geary.EngineError.NOT_FOUND(
                "No Graph folder for special use: %s",
                Geary.ObjectUtils.to_enum_nick(typeof(Geary.Folder.SpecialUse), special)
            );
        }
        return folder;
    }

    public override async Geary.Folder create_personal_folder(
        string name,
        Geary.Folder.SpecialUse use = Geary.Folder.SpecialUse.NONE,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        if (!this.is_account_open) {
            throw new Geary.EngineError.OPEN_REQUIRED("Account not open");
        }
        if (use != Geary.Folder.SpecialUse.NONE) {
            throw new Geary.EngineError.UNSUPPORTED(
                "Setting special-use on create is not supported for Graph accounts"
            );
        }
        Geary.Graph.Client.MailFolder created =
            yield this.client.create_mail_folder(name, cancellable);
        Geary.FolderPath path = this.remote_folder_root.get_child(created.display_name);
        Geary.Graph.Folder? existing = this.remote_folders.get(path) as Geary.Graph.Folder;
        if (existing != null) {
            return existing;
        }
        Geary.Graph.Folder folder = add_folder(
            created.display_name,
            created.id,
            Geary.Folder.SpecialUse.NONE
        );
        notify_folders_available_unavailable(
            sort_by_path(Collection.single(folder)),
            null
        );
        notify_folders_created(sort_by_path(Collection.single(folder)));
        return folder;
    }

    public override void register_local_folder(Geary.Folder local)
        throws GLib.Error {
        Geary.FolderPath path = local.path;
        if (this.local_folders.has_key(path)) {
            throw new Geary.EngineError.ALREADY_EXISTS(
                "Folder already registered: %s", path.to_string()
            );
        }
        if (!this.local_folder_root.is_descendant(path)) {
            throw new Geary.EngineError.NOT_FOUND(
                "Not a descendant of local folder root: %s", path.to_string()
            );
        }
        this.local_folders.set(path, local);
        notify_folders_available_unavailable(sort_by_path(Collection.single(local)), null);
    }

    public override void deregister_local_folder(Geary.Folder local)
        throws GLib.Error {
        Geary.FolderPath path = local.path;
        if (!this.local_folders.has_key(path)) {
            throw new Geary.EngineError.NOT_FOUND(
                "Unknown local folder: %s", path.to_string()
            );
        }
        notify_folders_available_unavailable(null, sort_by_path(Collection.single(local)));
        this.local_folders.unset(path);
    }

    public override async Gee.MultiMap<Geary.Email, Geary.FolderPath?>? local_search_message_id_async(
        Geary.RFC822.MessageID message_id,
        Geary.Email.Field requested_fields,
        bool partial_ok,
        Gee.Collection<Geary.FolderPath?>? folder_blacklist,
        Geary.EmailFlags? flag_blacklist,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        Geary.Email.Field required = requested_fields;
        if (flag_blacklist != null) {
            required = required | Geary.Email.Field.FLAGS;
        }

        Gee.HashMultiMap<Geary.Email, Geary.FolderPath?> matches =
            new Gee.HashMultiMap<Geary.Email, Geary.FolderPath?>();
        string needle = message_id.to_rfc822_string();
        foreach (Geary.Folder folder in this.remote_folders.values) {
            if (folder_blacklist != null && folder_blacklist.contains(folder.path)) {
                continue;
            }
            Geary.Graph.Folder? graph = folder as Geary.Graph.Folder;
            if (graph == null) {
                continue;
            }
            if (!graph.is_cache_loaded &&
                folder.used_as == Geary.Folder.SpecialUse.SENT) {
                graph.load_persisted_cache();
            }
            if (!graph.is_cache_loaded) {
                continue;
            }
            foreach (Geary.Email cached in graph.list_cached_emails()) {
                if (!matches_message_id(cached, needle)) {
                    continue;
                }
                Geary.Email email = cached;
                if (!partial_ok && !email.fields.fulfills(required)) {
                    email = yield graph.fetch_email_async(
                        cached.id,
                        required,
                        Geary.Folder.ListFlags.NONE,
                        cancellable
                    );
                }
                if (!partial_ok && !email.fields.fulfills(required)) {
                    continue;
                }
                if (flag_blacklist != null &&
                    email.email_flags != null &&
                    email.email_flags.contains_any(flag_blacklist)) {
                    continue;
                }
                matches.set(email, folder.path);
            }
        }
        return matches.size > 0 ? matches : null;
    }

    public override async Geary.Email local_fetch_email_async(
        Geary.EmailIdentifier email_id,
        Geary.Email.Field required_fields,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        foreach (Geary.Folder folder in this.remote_folders.values) {
            Geary.Graph.Folder? graph = folder as Geary.Graph.Folder;
            if (graph != null && graph.has_cached_identifier(email_id)) {
                return yield graph.fetch_email_async(
                    email_id,
                    required_fields,
                    Geary.Folder.ListFlags.NONE,
                    cancellable
                );
            }
        }
        throw new Geary.EngineError.NOT_FOUND(
            "Unknown Graph email identifier: %s", email_id.to_string()
        );
    }

    public override async Gee.List<Geary.Email> list_local_email_async(
        Gee.Collection<Geary.EmailIdentifier> ids,
        Geary.Email.Field required_fields,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        Gee.ArrayList<Geary.Email> listed = new Gee.ArrayList<Geary.Email>();
        foreach (Geary.EmailIdentifier id in ids) {
            listed.add(yield local_fetch_email_async(id, required_fields, cancellable));
        }
        return listed;
    }

    public override Geary.SearchQuery new_search_query(
        Gee.List<Geary.SearchQuery.Term> expression,
        string text
    ) throws GLib.Error {
        return new Geary.Graph.SearchQuery(expression, text);
    }

    public override async Gee.Collection<Geary.EmailIdentifier>? local_search_async(
        Geary.SearchQuery query,
        int limit = 100,
        int offset = 0,
        Gee.Collection<Geary.FolderPath?>? folder_blacklist = null,
        Gee.Collection<Geary.EmailIdentifier>? search_ids = null,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        return null;
    }

    public override async Gee.Set<string>? get_search_matches_async(
        Geary.SearchQuery query,
        Gee.Collection<Geary.EmailIdentifier> ids,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        return null;
    }

    public override async Gee.MultiMap<Geary.EmailIdentifier, Geary.FolderPath>? get_containing_folders_async(
        Gee.Collection<Geary.EmailIdentifier> ids,
        GLib.Cancellable? cancellable
    ) throws GLib.Error {
        Gee.HashMultiMap<Geary.EmailIdentifier, Geary.FolderPath> containing =
            new Gee.HashMultiMap<Geary.EmailIdentifier, Geary.FolderPath>();
        foreach (Geary.Folder folder in this.remote_folders.values) {
            Geary.Graph.Folder? graph = folder as Geary.Graph.Folder;
            if (graph == null || !graph.is_cache_loaded) {
                continue;
            }
            foreach (Geary.EmailIdentifier id in ids) {
                if (graph.has_cached_identifier(id)) {
                    containing.set(id, folder.path);
                }
            }
        }
        return containing.size > 0 ? containing : null;
    }

    public override async void cleanup_storage(GLib.Cancellable? cancellable)
        throws GLib.Error {
    }

    public override async void send_composed_email_async(
        Geary.ComposedEmail composed,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        yield this.client.send_composed_email(
            composed,
            true,
            cancellable
        );
        Geary.Graph.Folder? sent =
            this.get_graph_special_folder(Geary.Folder.SpecialUse.SENT);
        if (sent != null && sent.is_cache_loaded) {
            yield sent.refresh_async(true, cancellable);
        }
    }

    protected override void
        notify_folders_available_unavailable(Gee.BidirSortedSet<Geary.Folder>? available,
                                             Gee.BidirSortedSet<Geary.Folder>? unavailable) {
        base.notify_folders_available_unavailable(available, unavailable);
        if (available != null) {
            foreach (Geary.Folder folder in available) {
                folder.email_appended.connect(notify_email_appended);
                folder.email_inserted.connect(notify_email_inserted);
                folder.email_removed.connect(notify_email_removed);
                folder.email_locally_removed.connect(notify_email_locally_removed);
                folder.email_locally_complete.connect(notify_email_locally_complete);
                folder.email_flags_changed.connect(notify_email_flags_changed);
            }
        }
        if (unavailable != null) {
            foreach (Geary.Folder folder in unavailable) {
                folder.email_appended.disconnect(notify_email_appended);
                folder.email_inserted.disconnect(notify_email_inserted);
                folder.email_removed.disconnect(notify_email_removed);
                folder.email_locally_removed.disconnect(notify_email_locally_removed);
                folder.email_locally_complete.disconnect(notify_email_locally_complete);
                folder.email_flags_changed.disconnect(notify_email_flags_changed);
            }
        }
    }

    internal Geary.Graph.Folder? get_graph_folder(Geary.FolderPath path) {
        return this.remote_folders.get(path) as Geary.Graph.Folder;
    }

    internal Geary.Graph.Folder? get_graph_special_folder(Geary.Folder.SpecialUse use) {
        return this.special_folders.get(use);
    }

    private Geary.Graph.Folder add_folder(string name,
                                          string graph_id,
                                          Geary.Folder.SpecialUse use) {
        Geary.FolderPath path = this.remote_folder_root.get_child(name);
        Geary.Graph.Folder folder = new Geary.Graph.Folder(
            this,
            this.client,
            path,
            graph_id,
            use
        );
        this.remote_folders.set(path, folder);
        if (use != Geary.Folder.SpecialUse.NONE) {
            this.special_folders.set(use, folder);
        }
        return folder;
    }

    private static bool matches_message_id(Geary.Email email, string needle) {
        if (email.message_id != null &&
            email.message_id.to_rfc822_string() == needle) {
            return true;
        }
        Gee.Set<Geary.RFC822.MessageID>? ancestors = email.get_ancestors();
        if (ancestors == null) {
            return false;
        }
        foreach (Geary.RFC822.MessageID candidate in ancestors) {
            if (candidate.to_rfc822_string() == needle) {
                return true;
            }
        }
        return false;
    }

    private void queue_prefetch_refresh() {
        if (!this.is_account_open) {
            return;
        }
        if (this.prefetch_refresh_running) {
            this.prefetch_refresh_pending = true;
            return;
        }
        this.prefetch_refresh_running = true;
        refresh_loaded_folders_for_prefetch.begin((obj, res) => {
            try {
                refresh_loaded_folders_for_prefetch.end(res);
            } catch (GLib.Error err) {
                warning("Error refreshing Graph folders after prefetch change: %s", err.message);
            }
            this.prefetch_refresh_running = false;
            if (this.prefetch_refresh_pending) {
                this.prefetch_refresh_pending = false;
                queue_prefetch_refresh();
            }
        });
    }

    private async void refresh_loaded_folders_for_prefetch() throws GLib.Error {
        if (!this.is_account_open) {
            return;
        }
        foreach (Geary.Folder folder in this.remote_folders.values) {
            if (!this.is_account_open) {
                return;
            }
            Geary.Graph.Folder? graph = folder as Geary.Graph.Folder;
            if (graph == null) {
                continue;
            }
            if (graph.used_as == Geary.Folder.SpecialUse.INBOX) {
                graph.load_persisted_cache();
            } else if (!graph.is_cache_loaded) {
                continue;
            }
            yield graph.refresh_async(true, null);
        }
    }

}

internal class Geary.Graph.NoopContactStore : Geary.BaseObject, Geary.ContactStore {

    public async Geary.Contact? get_by_rfc822(
        Geary.RFC822.MailboxAddress address,
        GLib.Cancellable? cancellable
    ) throws GLib.Error {
        return null;
    }

    public async Gee.Collection<Geary.Contact> search(
        string query,
        uint min_importance,
        uint limit,
        GLib.Cancellable? cancellable
    ) throws GLib.Error {
        return new Gee.ArrayList<Geary.Contact>();
    }

    public async void update_contacts(
        Gee.Collection<Geary.Contact> updated,
        GLib.Cancellable? cancellable
    ) throws GLib.Error {
    }

}
