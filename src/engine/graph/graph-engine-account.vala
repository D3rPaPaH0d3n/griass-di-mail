/*
 * Copyright 2026 Daniel Elia <d.elia@outlook.com>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

internal class Geary.Graph.Account : Geary.Account,
    Geary.AccountSupport.QueueSend {

    private const string REMOTE_ROOT_LABEL = "$geary-graph";
    private const uint POLL_INTERVAL_SEC = 60;
    // Every Nth poll tick runs a full sync instead of the fast poll: the
    // folder list is re-synced and all cache-loaded folders are refreshed,
    // not just the inbox and open folders.
    private const uint FULL_SYNC_EVERY_N_TICKS = 5;

    // Well-known names used by Microsoft Graph for the built-in special folders.
    // These are already registered as hardcoded folders, so we skip them when
    // syncing custom (user-created) folders from the API.
    private const string[] BUILTIN_WELL_KNOWN_NAMES = {
        "inbox",
        "sentitems",
        "drafts",
        "deleteditems",
        "junkemail",
        "archive",
        "outbox",
    };

    // Display names that Microsoft Graph uses for built-in folders in English
    // and a selection of other locales. Used as a secondary filter when the
    // wellKnownName field is absent from the API response.
    private const string[] BUILTIN_DISPLAY_NAMES = {
        // English
        "inbox",
        "sent items",
        "sent",
        "drafts",
        "deleted items",
        "junk email",
        "junk",
        "archive",
        "outbox",
        "conversation history",
        "rss feeds",
        "sync issues",
    };

    private Geary.FolderRoot remote_folder_root =
        new Geary.FolderRoot(REMOTE_ROOT_LABEL, false);
    private Gee.TreeMap<Geary.FolderPath,Geary.Folder> remote_folders =
        new Gee.TreeMap<Geary.FolderPath,Geary.Folder>((a, b) => a.compare_to(b));
    private Gee.TreeMap<Geary.FolderPath,Geary.Folder> local_folders =
        new Gee.TreeMap<Geary.FolderPath,Geary.Folder>((a, b) => a.compare_to(b));
    private Gee.HashMap<Geary.Folder.SpecialUse,Geary.Graph.Folder> special_folders =
        new Gee.HashMap<Geary.Folder.SpecialUse,Geary.Graph.Folder>();

    private Gee.ArrayList<Geary.Folder> get_remote_folder_snapshot() {
        Gee.ArrayList<Geary.Folder> folders = new Gee.ArrayList<Geary.Folder>();
        folders.add_all(this.remote_folders.values);
        return folders;
    }

    private Geary.Graph.Client client;
    private Geary.TimeoutManager poll_timer;
    private uint poll_tick = 0;
    private GLib.Cancellable? poll_cancellable = null;
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
        this.poll_timer = new Geary.TimeoutManager.seconds(
            POLL_INTERVAL_SEC,
            on_poll_tick
        );
        this.poll_timer.repetition = Geary.TimeoutManager.Repeat.FOREVER;
        this.poll_timer.start();
        this.information.notify["prefetch-period-days"].connect((obj, pspec) => {
            queue_prefetch_refresh();
        });

        add_folder("Inbox", "inbox", Geary.Folder.SpecialUse.INBOX);
        add_folder("Sent", "sentitems", Geary.Folder.SpecialUse.SENT);
        add_folder("Drafts", "drafts", Geary.Folder.SpecialUse.DRAFTS);
        add_folder("Trash", "deleteditems", Geary.Folder.SpecialUse.TRASH);
        add_folder("Junk", "junkemail", Geary.Folder.SpecialUse.JUNK);
        add_folder("Archive", "archive", Geary.Folder.SpecialUse.ARCHIVE);
        add_folder("Outbox", "outbox", Geary.Folder.SpecialUse.OUTBOX);
    }

    public override async void open_async(GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        if (this.is_account_open) {
            return;
        }

        yield this.incoming.start(cancellable);
        yield this.outgoing.start(cancellable);

        this.is_account_open = true;

        // Sync custom folders from the server before notifying availability,
        // so the full folder list is presented to the UI in one shot.
        try {
            yield sync_custom_folders_async(cancellable);
        } catch (GLib.Error err) {
            debug("Graph: Failed to sync custom folders on open: %s", err.message);
        }

        notify_folders_available_unavailable(
            sort_by_path(get_remote_folder_snapshot()),
            null
        );
        notify_opened();
        Geary.Graph.Folder? inbox =
            this.get_graph_special_folder(Geary.Folder.SpecialUse.INBOX);
        if (inbox != null) {
            inbox.load_persisted_cache();
        }
        // Load Junk as well so its unread counter is available without
        // manually opening the folder.
        Geary.Graph.Folder? junk =
            this.get_graph_special_folder(Geary.Folder.SpecialUse.JUNK);
        if (junk != null) {
            junk.load_persisted_cache();
        }
        queue_prefetch_refresh();
    }

    public override async void close_async(GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        if (!this.is_account_open) {
            return;
        }

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
        Gee.ArrayList<Geary.Folder> folders = get_remote_folder_snapshot();
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
        foreach (Geary.Folder folder in get_remote_folder_snapshot()) {
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
                    if (graph.get_open_state() != Geary.Folder.OpenState.CLOSED) {
                        email = yield graph.fetch_email_async(
                            cached.id,
                            required,
                            Geary.Folder.ListFlags.NONE,
                            cancellable
                        );
                    } else {
                        continue;
                    }
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
        foreach (Geary.Folder folder in get_remote_folder_snapshot()) {
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
        Gee.Set<Geary.EmailIdentifier>? search_scope = null;
        if (search_ids != null) {
            search_scope = new Gee.HashSet<Geary.EmailIdentifier>();
            search_scope.add_all(search_ids);
        }

        Gee.ArrayList<Geary.Email> matched = new Gee.ArrayList<Geary.Email>();
        Gee.Set<Geary.EmailIdentifier> seen = new Gee.HashSet<Geary.EmailIdentifier>();
        foreach (Geary.Folder folder in get_remote_folder_snapshot()) {
            if (cancellable != null && cancellable.is_cancelled()) {
                throw new GLib.IOError.CANCELLED("Graph search cancelled");
            }
            if (folder_blacklist != null && folder_blacklist.contains(folder.path)) {
                continue;
            }
            Geary.Graph.Folder? graph = folder as Geary.Graph.Folder;
            if (graph == null) {
                continue;
            }
            if (!graph.is_cache_loaded) {
                graph.load_persisted_cache();
            }
            if (!graph.is_cache_loaded) {
                continue;
            }
            foreach (Geary.Email email in graph.list_cached_emails()) {
                if (search_scope != null && !search_scope.contains(email.id)) {
                    continue;
                }
                if (!email_matches_query(email, query)) {
                    continue;
                }
                if (seen.add(email.id)) {
                    matched.add(email);
                }
            }
        }

        if (matched.is_empty) {
            return null;
        }
        matched.sort((a, b) => Geary.Email.compare_recv_date_descending(a, b));

        int start = int.max(0, offset);
        int max_results = (limit > 0) ? limit : matched.size;
        if (start >= matched.size || max_results <= 0) {
            return null;
        }

        Gee.ArrayList<Geary.EmailIdentifier> ids =
            new Gee.ArrayList<Geary.EmailIdentifier>();
        for (int i = start; i < matched.size && ids.size < max_results; i++) {
            ids.add(matched[i].id);
        }
        return ids.is_empty ? null : ids;
    }

    public override async Gee.Set<string>? get_search_matches_async(
        Geary.SearchQuery query,
        Gee.Collection<Geary.EmailIdentifier> ids,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        Gee.Set<Geary.EmailIdentifier> id_set = new Gee.HashSet<Geary.EmailIdentifier>();
        id_set.add_all(ids);

        Gee.Set<string> matches = new Gee.HashSet<string>();
        foreach (Geary.Folder folder in get_remote_folder_snapshot()) {
            if (cancellable != null && cancellable.is_cancelled()) {
                throw new GLib.IOError.CANCELLED("Graph search matches cancelled");
            }
            Geary.Graph.Folder? graph = folder as Geary.Graph.Folder;
            if (graph == null) {
                continue;
            }
            if (!graph.is_cache_loaded) {
                graph.load_persisted_cache();
            }
            if (!graph.is_cache_loaded) {
                continue;
            }
            foreach (Geary.Email email in graph.list_cached_emails()) {
                if (!id_set.contains(email.id)) {
                    continue;
                }
                Gee.Set<string>? email_matches = get_query_matches(email, query);
                if (email_matches != null) {
                    matches.add_all(email_matches);
                }
            }
        }
        return matches.is_empty ? null : matches;
    }

    public override async Gee.MultiMap<Geary.EmailIdentifier, Geary.FolderPath>? get_containing_folders_async(
        Gee.Collection<Geary.EmailIdentifier> ids,
        GLib.Cancellable? cancellable
    ) throws GLib.Error {
        Gee.HashMultiMap<Geary.EmailIdentifier, Geary.FolderPath> containing =
            new Gee.HashMultiMap<Geary.EmailIdentifier, Geary.FolderPath>();
        foreach (Geary.Folder folder in get_remote_folder_snapshot()) {
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

    public override async void send_composed_email(
        Geary.ComposedEmail composed,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        string message_id = yield save_email(composed, cancellable);
        yield queue_email(message_id, cancellable);
    }

    /**
     * Stages a composed email into Outlook's Outbox folder without sending it.
     *
     * Returns the Graph message ID of the staged message. Pass it to
     * {@link queue_email} to deliver it, or to {@link discard_staged_email}
     * to remove it (undo).
     */
    public async string save_email(
        Geary.ComposedEmail composed,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        string message_id =
            yield this.client.create_message_in_outbox(composed, cancellable);
        // Refresh Drafts and Outbox so the staged message moves cleanly in
        // the folder views once the draft is relocated.
        Geary.Graph.Folder? drafts =
            this.get_graph_special_folder(Geary.Folder.SpecialUse.DRAFTS);
        if (drafts != null && drafts.is_cache_loaded) {
            yield drafts.refresh_async(true, cancellable);
        }
        Geary.Graph.Folder? outbox =
            this.get_graph_special_folder(Geary.Folder.SpecialUse.OUTBOX);
        if (outbox != null && outbox.is_cache_loaded) {
            yield outbox.refresh_async(true, cancellable);
        }
        return message_id;
    }

    /**
     * Sends a message previously staged by {@link save_email}.
     *
     * The server delivers the message and moves it to Sent Items automatically.
     */
    public async void queue_email(
        string message_id,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        yield this.client.send_message(message_id, cancellable);
        email_sent();
        // Refresh Sent so the newly-delivered message shows up
        Geary.Graph.Folder? sent =
            this.get_graph_special_folder(Geary.Folder.SpecialUse.SENT);
        if (sent != null && sent.is_cache_loaded) {
            yield sent.refresh_async(true, cancellable);
        }
        // Refresh Outbox so the now-sent message disappears
        Geary.Graph.Folder? outbox =
            this.get_graph_special_folder(Geary.Folder.SpecialUse.OUTBOX);
        if (outbox != null && outbox.is_cache_loaded) {
            yield outbox.refresh_async(true, cancellable);
        }
    }

    /**
     * Discards a message previously staged by {@link save_email} (undo send).
     */
    public async void discard_staged_email(
        string message_id,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        yield this.client.delete_message(message_id, cancellable);
        Geary.Graph.Folder? outbox =
            this.get_graph_special_folder(Geary.Folder.SpecialUse.OUTBOX);
        if (outbox != null && outbox.is_cache_loaded) {
            yield outbox.refresh_async(true, cancellable);
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

    private void remove_folder(Geary.FolderPath path) {
        Geary.Folder? folder = this.remote_folders.get(path);
        if (folder == null) {
            return;
        }
        this.remote_folders.unset(path);
        notify_folders_available_unavailable(
            null,
            sort_by_path(Collection.single(folder))
        );
        notify_folders_deleted(sort_by_path(Collection.single(folder)));
    }

    private async void sync_custom_folders_async(
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        Gee.List<Geary.Graph.Client.MailFolder> server_folders =
            yield this.client.list_mail_folders(cancellable);

        // Build a set of well-known names to skip
        Gee.HashSet<string> builtin_names = new Gee.HashSet<string>();
        foreach (string name in BUILTIN_WELL_KNOWN_NAMES) {
            builtin_names.add(name);
        }

        // Build a set of built-in display names for secondary filtering
        Gee.HashSet<string> builtin_display_names = new Gee.HashSet<string>();
        foreach (string name in BUILTIN_DISPLAY_NAMES) {
            builtin_display_names.add(name);
        }

        // Build a map of graph_id -> server folder for the custom folders
        // (those whose wellKnownName is empty or not in our builtins list)
        Gee.HashMap<string,Geary.Graph.Client.MailFolder> server_custom =
            new Gee.HashMap<string,Geary.Graph.Client.MailFolder>();
        foreach (Geary.Graph.Client.MailFolder mf in server_folders) {
            if (mf.is_hidden) {
                continue;
            }
            // Primary filter: skip by wellKnownName when the API returned it
            if (!String.is_empty(mf.well_known_name) &&
                builtin_names.contains(mf.well_known_name.down())) {
                continue;
            }
            // Secondary filter: when wellKnownName is absent, skip by displayName
            // so that built-in folders whose API response omitted the field are
            // still excluded (e.g. "Sent Items", "Deleted Items", "Outbox", …).
            if (String.is_empty(mf.well_known_name) &&
                builtin_display_names.contains(mf.display_name.down())) {
                continue;
            }
            if (String.is_empty(mf.display_name)) {
                continue;
            }
            server_custom.set(mf.id, mf);
        }

        // Build a map of graph_id -> path for currently tracked custom folders
        // (those not bound to a special use, i.e. not one of the hardcoded builtins)
        Gee.HashMap<string,Geary.FolderPath> local_custom =
            new Gee.HashMap<string,Geary.FolderPath>();
        foreach (Geary.Folder folder in get_remote_folder_snapshot()) {
            Geary.Graph.Folder? graph = folder as Geary.Graph.Folder;
            if (graph != null && graph.used_as == Geary.Folder.SpecialUse.NONE) {
                local_custom.set(graph.graph_folder_id, folder.path);
            }
        }

        // Add folders present on the server but not yet tracked locally
        Gee.ArrayList<Geary.Folder> added = new Gee.ArrayList<Geary.Folder>();
        foreach (Geary.Graph.Client.MailFolder mf in server_custom.values) {
            if (!local_custom.has_key(mf.id)) {
                // Guard against a display_name that collides with an already-registered
                // folder path (e.g. a user folder literally named "Inbox").
                Geary.FolderPath candidate =
                    this.remote_folder_root.get_child(mf.display_name);
                if (this.remote_folders.has_key(candidate)) {
                    debug(
                        "Graph: Skipping custom folder '%s' (%s): path already registered",
                        mf.display_name, mf.id
                    );
                    continue;
                }
                Geary.Graph.Folder folder = add_folder(
                    mf.display_name,
                    mf.id,
                    Geary.Folder.SpecialUse.NONE
                );
                added.add(folder);
                debug("Graph: Added custom folder '%s' (%s)", mf.display_name, mf.id);
            }
        }

        // Remove folders that no longer exist on the server
        foreach (var entry in local_custom.entries) {
            if (!server_custom.has_key(entry.key)) {
                Geary.FolderPath path = entry.value;
                debug("Graph: Removing custom folder '%s' (no longer on server)", path.to_string());
                remove_folder(path);
            }
        }

        // Notify the UI about newly discovered folders (only after account is open,
        // otherwise open_async itself will fire the initial availability notification)
        if (this.is_account_open && !added.is_empty) {
            notify_folders_available_unavailable(
                sort_by_path(added),
                null
            );
            notify_folders_created(sort_by_path(added));
        }
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

    private static bool email_matches_query(Geary.Email email, Geary.SearchQuery query) {
        if (query.expression.is_empty) {
            return !String.is_empty(query.raw) &&
                matches_text_term(
                    email,
                    Geary.SearchQuery.EmailTextTerm.Property.ALL,
                    query.raw
                );
        }
        foreach (Geary.SearchQuery.Term term in query.expression) {
            if (!matches_query_term(email, term)) {
                return false;
            }
        }
        return true;
    }

    private static Gee.Set<string>? get_query_matches(Geary.Email email, Geary.SearchQuery query) {
        Gee.Set<string> matches = new Gee.HashSet<string>();
        if (query.expression.is_empty) {
            if (!String.is_empty(query.raw) &&
                matches_text_term(
                    email,
                    Geary.SearchQuery.EmailTextTerm.Property.ALL,
                    query.raw
                )) {
                matches.add(query.raw);
            }
            return matches.is_empty ? null : matches;
        }
        foreach (Geary.SearchQuery.Term term in query.expression) {
            Geary.SearchQuery.EmailTextTerm? text =
                term as Geary.SearchQuery.EmailTextTerm;
            if (text == null || term.is_negated) {
                continue;
            }
            foreach (string value in text.terms) {
                if (matches_text_term(email, text.target, value)) {
                    matches.add(value);
                }
            }
        }
        return matches.is_empty ? null : matches;
    }

    private static bool matches_query_term(Geary.Email email, Geary.SearchQuery.Term term) {
        Geary.SearchQuery.EmailTextTerm? text =
            term as Geary.SearchQuery.EmailTextTerm;
        if (text != null) {
            bool any = false;
            foreach (string value in text.terms) {
                if (matches_text_term(email, text.target, value)) {
                    any = true;
                    break;
                }
            }
            return term.is_negated ? !any : any;
        }

        Geary.SearchQuery.EmailFlagTerm? flag =
            term as Geary.SearchQuery.EmailFlagTerm;
        if (flag != null) {
            bool set = (email.email_flags != null &&
                        email.email_flags.contains(flag.value));
            return term.is_negated ? !set : set;
        }
        return true;
    }

    private static bool matches_text_term(Geary.Email email,
                                          Geary.SearchQuery.EmailTextTerm.Property target,
                                          string term) {
        if (String.is_empty(term)) {
            return false;
        }
        string needle = term.down();
        switch (target) {
        case Geary.SearchQuery.EmailTextTerm.Property.TO:
            return matches_addresses_text(email.to, needle);
        case Geary.SearchQuery.EmailTextTerm.Property.CC:
            return matches_addresses_text(email.cc, needle);
        case Geary.SearchQuery.EmailTextTerm.Property.BCC:
            return matches_addresses_text(email.bcc, needle);
        case Geary.SearchQuery.EmailTextTerm.Property.FROM:
            return matches_addresses_text(email.from, needle);
        case Geary.SearchQuery.EmailTextTerm.Property.SUBJECT:
            return matches_subject_text(email.subject, needle);
        case Geary.SearchQuery.EmailTextTerm.Property.BODY:
            return matches_preview_text(email.preview, needle);
        case Geary.SearchQuery.EmailTextTerm.Property.ATTACHMENT_NAME:
            return matches_string_text(email.get_searchable_attachment_list(), needle);
        case Geary.SearchQuery.EmailTextTerm.Property.ALL:
            return (
                matches_subject_text(email.subject, needle) ||
                matches_addresses_text(email.from, needle) ||
                matches_addresses_text(email.to, needle) ||
                matches_addresses_text(email.cc, needle) ||
                matches_addresses_text(email.bcc, needle) ||
                matches_preview_text(email.preview, needle) ||
                matches_string_text(email.get_searchable_attachment_list(), needle)
            );
        default:
            return false;
        }
    }

    private static bool matches_subject_text(Geary.RFC822.Subject? value, string needle) {
        return value != null && value.to_searchable_string().down().contains(needle);
    }

    private static bool matches_preview_text(Geary.RFC822.Text? value, string needle) {
        if (value == null) {
            return false;
        }
        string haystack = ((string) value.buffer.get_bytes().get_data()).make_valid().down();
        return haystack.contains(needle);
    }

    private static bool matches_addresses_text(Geary.RFC822.MailboxAddresses? value, string needle) {
        return value != null && value.to_searchable_string().down().contains(needle);
    }

    private static bool matches_string_text(string? value, string needle) {
        return !String.is_empty(value) && value.down().contains(needle);
    }

    internal void cancel_active_poll() {
        if (this.poll_cancellable != null) {
            this.poll_cancellable.cancel();
            this.poll_cancellable = null;
        }
    }

    internal void trigger_immediate_poll() {
        cancel_active_poll();
        // User actions can affect closed folders (e.g. delete moves mail to
        // an unopened Trash), so immediate polls cover cache-loaded folders
        // too, not just open ones.
        queue_folder_poll(true);
        this.poll_timer.start();
    }

    private void on_poll_tick() {
        if (!GLib.NetworkMonitor.get_default().network_available) {
            return;
        }
        this.poll_tick++;
        if (this.poll_tick % FULL_SYNC_EVERY_N_TICKS == 0) {
            queue_prefetch_refresh();
        } else {
            queue_folder_poll(false);
        }
    }

    private void queue_folder_poll(bool include_cached) {
        var cancellable = new GLib.Cancellable();
        this.poll_cancellable = cancellable;
        poll_folders_refresh.begin(include_cached, cancellable, (obj, res) => {
            try {
                poll_folders_refresh.end(res);
            } catch (GLib.Error err) {
                if (!(err is GLib.IOError.CANCELLED)) {
                    debug("Graph: folder refresh poll error: %s", err.message);
                }
            }
            if (this.poll_cancellable == cancellable) {
                this.poll_cancellable = null;
            }
        });
    }

    private async void poll_folders_refresh(bool include_cached,
                                            GLib.Cancellable? cancellable)
        throws GLib.Error {
        foreach (Geary.Folder folder in get_remote_folder_snapshot()) {
            if (cancellable != null && cancellable.is_cancelled()) {
                return;
            }
            Geary.Graph.Folder? graph = folder as Geary.Graph.Folder;
            if (graph == null) {
                continue;
            }
            bool is_open =
                graph.get_open_state() != Geary.Folder.OpenState.CLOSED;
            if (graph.used_as == Geary.Folder.SpecialUse.INBOX) {
                graph.load_persisted_cache();
            } else if (!is_open && !(include_cached && graph.is_cache_loaded)) {
                // The regular poll only covers the inbox and open folders;
                // cache-loaded closed folders sync on the full-sync tick or
                // on immediate (user-action) polls.
                continue;
            }
            try {
                yield graph.refresh_async(true, cancellable);
            } catch (GLib.Error err) {
                if (err is GLib.IOError.CANCELLED) {
                    return;
                }
                debug("Graph: folder refresh poll error for %s: %s",
                    graph.path.to_string(), err.message);
            }
        }
    }

    private void queue_prefetch_refresh() {
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
        // Re-sync custom folders on every refresh cycle so that folders created
        // or deleted by another client (e.g. OWA, Outlook) are reflected here.
        if (this.is_account_open) {
            try {
                yield sync_custom_folders_async(null);
            } catch (GLib.Error err) {
                debug("Graph: Failed to sync custom folders during refresh: %s", err.message);
            }
        }

        // When running in background (account closed), only refresh the Inbox
        // to avoid unnecessary work. When account is open, refresh all loaded
        // folders for proper synchronization.
        bool background_mode = !this.is_account_open;

        foreach (Geary.Folder folder in get_remote_folder_snapshot()) {
            Geary.Graph.Folder? graph = folder as Geary.Graph.Folder;
            if (graph == null) {
                continue;
            }

            if (background_mode && graph.used_as != Geary.Folder.SpecialUse.INBOX) {
                continue;
            }

            if (graph.used_as == Geary.Folder.SpecialUse.INBOX) {
                graph.load_persisted_cache();
            } else if (!graph.is_cache_loaded) {
                // Never-opened folders have nothing to keep fresh; they load
                // on first open instead of costing a request every cycle.
                continue;
            }

            try {
                yield graph.refresh_async(true, null);
            } catch (GLib.Error err) {
                debug("Graph: folder refresh error for %s: %s",
                    graph.path.to_string(), err.message);
            }
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
