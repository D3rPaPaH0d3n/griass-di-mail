/*
 * Copyright 2026 Daniel Elia <d.elia@outlook.com>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

internal class Convey.Graph.Folder : Convey.AbstractLocalFolder,
    Convey.FolderSupport.Mark,
    Convey.FolderSupport.Move,
    Convey.FolderSupport.Archive,
    Convey.FolderSupport.Remove,
    Convey.FolderSupport.Create,
    Convey.FolderSupport.Copy,
    Convey.FolderSupport.Empty {

    private const int MIN_REFRESH_BATCH = 25;
    private const int MAX_REFRESH_BATCH = 500;
    // Page size for the periodic new-mail poll; usually one page suffices.
    private const int POLL_BATCH = 20;
    private const int64 REMOVED_GRACE_USEC = 5 * 1000 * 1000;

    private Convey.Graph.Account owner;
    private Convey.Graph.Client client;
    private Convey.Graph.FolderProperties _properties =
        new Convey.Graph.FolderProperties(0, 0);
    private Convey.FolderPath _path;
    private Convey.Folder.SpecialUse _used_as;
    private string folder_id;

    private Gee.ArrayList<Convey.Email> email_cache =
        new Gee.ArrayList<Convey.Email>();
    private Gee.HashMap<string,Convey.Email> email_by_id =
        new Gee.HashMap<string,Convey.Email>();
    private Gee.HashMap<string,Convey.Graph.Client.Message> message_by_id =
        new Gee.HashMap<string,Convey.Graph.Client.Message>();
    private bool is_loaded = false;
    // Graph delta cursor, persisted with the cache after every applied
    // batch; empty means the next sync establishes a fresh baseline.
    private string delta_link = "";
    // Set when the server rejects delta queries; sync falls back to
    // newest-first polling for the rest of the session.
    private bool delta_unsupported = false;
    private bool sync_running = false;
    private string? cache_path = null;
    // graph_id → monotonic removal time; suppresses stale server echoes
    private Gee.HashMap<string, int64?> recently_removed =
        new Gee.HashMap<string, int64?>();


    public override Convey.Account account { get { return this.owner; } }
    public override Convey.FolderProperties properties { get { return this._properties; } }
    public override Convey.FolderPath path { get { return this._path; } }
    public override Convey.Folder.SpecialUse used_as { get { return this._used_as; } }
    internal bool is_cache_loaded { get { return this.is_loaded; } }
    internal bool is_delta_unsupported { get { return this.delta_unsupported; } }
    internal string graph_folder_id { get { return this.folder_id; } }


    public Folder(Convey.Graph.Account owner,
                  Convey.Graph.Client client,
                  Convey.FolderPath path,
                  string folder_id,
                  Convey.Folder.SpecialUse used_as) {
        this.owner = owner;
        this.client = client;
        this._path = path;
        this.folder_id = folder_id;
        this._used_as = used_as;
        this.cache_path = compute_cache_path();
    }

    public override async bool open_async(Convey.Folder.OpenFlags open_flags,
                                          GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        bool opened = yield base.open_async(open_flags, cancellable);
        if (opened) {
            // Browsing folders means the user is watching for mail; return
            // to the fast poll cadence.
            this.owner.note_user_activity();
            load_persisted_cache();
            if (this.is_loaded) {
                refresh_async.begin(true, null, (obj, res) => {
                    try {
                        refresh_async.end(res);
                    } catch (GLib.IOError.CANCELLED err) {
                    } catch (GLib.Error err) {
                        warning("Error refreshing Graph folder %s: %s", this.path.to_string(), err.message);
                    }
                });
            } else {
                yield refresh_async(true, cancellable);
            }
        }
        return opened;
    }

    internal void load_persisted_cache() {
        if (!this.is_loaded) {
            load_cached_messages();
        }
    }

    public override async void synchronise_remote(GLib.Cancellable? cancellable)
        throws GLib.Error {
        yield refresh_async(true, cancellable);
    }

    public override async Gee.Collection<Convey.EmailIdentifier> contains_identifiers(
        Gee.Collection<Convey.EmailIdentifier> ids,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        check_open();
        yield ensure_loaded(cancellable);

        Gee.HashSet<Convey.EmailIdentifier> contained = new Gee.HashSet<Convey.EmailIdentifier>();
        foreach (Convey.EmailIdentifier id in ids) {
            Convey.Graph.EmailIdentifier? graph = id as Convey.Graph.EmailIdentifier;
            if (graph != null && this.email_by_id.has_key(graph.graph_id)) {
                contained.add(id);
            }
        }
        return contained;
    }

    public override async Gee.List<Convey.Email>? list_email_by_id_async(
        Convey.EmailIdentifier? initial_id,
        int count,
        Convey.Email.Field required_fields,
        Convey.Folder.ListFlags flags,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        check_open();
        if (count <= 0) {
            return new Gee.ArrayList<Convey.Email>();
        }
        if (flags.is_force_update()) {
            yield refresh_async(true, cancellable);
        } else {
            yield ensure_loaded(cancellable);
        }

        Gee.ArrayList<Convey.Email> ordered = new Gee.ArrayList<Convey.Email>();
        if (flags.is_oldest_to_newest()) {
            for (int i = this.email_cache.size - 1; i >= 0; i--) {
                ordered.add(this.email_cache[i]);
            }
        } else {
            ordered.add_all(this.email_cache);
        }

        int start = 0;
        if (initial_id != null) {
            int index = find_index(ordered, initial_id);
            if (index >= 0) {
                start = flags.is_including_id() ? index : (index + 1);
            } else {
                throw new Convey.EngineError.NOT_FOUND(
                    "Unknown email identifier: %s", initial_id.to_string()
                );
            }
        }

        Gee.ArrayList<Convey.Email> listed = new Gee.ArrayList<Convey.Email>();
        for (int i = start; i < ordered.size && listed.size < count; i++) {
            Convey.Email email = ordered[i];
            if (!email.fields.fulfills(required_fields)) {
                email = yield fetch_email_async(
                    email.id,
                    required_fields,
                    flags,
                    cancellable
                );
            }
            listed.add(email);
        }
        return listed;
    }

    public override async Gee.List<Convey.Email>? list_email_by_sparse_id_async(
        Gee.Collection<Convey.EmailIdentifier> ids,
        Convey.Email.Field required_fields,
        Convey.Folder.ListFlags flags,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        if (is_open()) {
            if (flags.is_force_update()) {
                yield refresh_async(true, cancellable);
            } else {
                yield ensure_loaded(cancellable);
            }
        } else if (flags.is_force_update() || !this.is_loaded) {
            throw new Convey.EngineError.OPEN_REQUIRED("%s not open", to_string());
        }

        Gee.ArrayList<Convey.Email> listed = new Gee.ArrayList<Convey.Email>();
        foreach (Convey.EmailIdentifier id in ids) {
            Convey.Graph.EmailIdentifier? graph = id as Convey.Graph.EmailIdentifier;
            if (graph == null) {
                continue;
            }
            Convey.Email? email = this.email_by_id.get(graph.graph_id);
            if (email == null) {
                continue;
            }
            if (!email.fields.fulfills(required_fields)) {
                email = yield fetch_email_async(
                    email.id,
                    required_fields,
                    flags,
                    cancellable
                );
            }
            listed.add(email);
        }
        return listed;
    }

    public override async Convey.Email fetch_email_async(
        Convey.EmailIdentifier id,
        Convey.Email.Field required_fields,
        Convey.Folder.ListFlags flags,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        bool is_open_now = is_open();

        Convey.Graph.EmailIdentifier? graph = id as Convey.Graph.EmailIdentifier;
        if (graph == null) {
            throw new Convey.EngineError.BAD_PARAMETERS(
                "Not a Graph email identifier: %s", id.to_string()
            );
        }

        Convey.Email? email = this.email_by_id.get(graph.graph_id);
        bool needs_full_message =
            required_fields.requires_any(Convey.Email.Field.BODY | Convey.Email.Field.HEADER);

        if (is_open_now && needs_full_message &&
            (email == null || !email.fields.fulfills(required_fields))) {
            try {
                Convey.Graph.Client.Message full = yield this.client.fetch_message(
                    graph.graph_id, cancellable
                );
                this.message_by_id.set(full.id, full);
                if (email == null) {
                    email = build_email(full);
                } else {
                    build_email(full, email);
                }
                try {
                    Convey.Memory.Buffer full_rfc822 =
                        yield this.client.fetch_message_rfc822(
                            graph.graph_id,
                            cancellable
                        );
                    populate_full_message(email, full_rfc822, graph.graph_id);
                } catch (GLib.Error err) {
                    debug(
                        "Error fetching Graph RFC822 payload for %s: %s",
                        graph.graph_id,
                        err.message
                    );
                }
                persist_cached_messages();
            } catch (Convey.Graph.HttpError.NOT_FOUND err) {
                debug(
                    "Graph message %s not found, removing from cache",
                    graph.graph_id
                );
                Gee.ArrayList<Convey.EmailIdentifier> to_remove =
                    new Gee.ArrayList<Convey.EmailIdentifier>();
                to_remove.add(id);
                Gee.ArrayList<Convey.EmailIdentifier> removed =
                    remove_cached_emails(to_remove);
                if (!removed.is_empty) {
                    notify_email_removed(removed);
                }
                throw new Convey.EngineError.NOT_FOUND(
                    "Graph message not found on server: %s", graph.graph_id
                );
            }
        } else {
            if (is_open_now) {
                if (!this.is_loaded) {
                    yield ensure_loaded(cancellable);
                }
            } else if (!this.is_loaded) {
                throw new Convey.EngineError.OPEN_REQUIRED("%s not open", to_string());
            }

            if (email == null) {
                email = this.email_by_id.get(graph.graph_id);
                if (email == null) {
                    throw new Convey.EngineError.NOT_FOUND(
                        "Unknown Graph email identifier: %s", graph.graph_id
                    );
                }
            }
        }

        if (email == null) {
            throw new Convey.EngineError.NOT_FOUND(
                "Unknown Graph email identifier: %s", graph.graph_id
            );
        }

        if (!email.fields.fulfills(required_fields)) {
            throw new Convey.EngineError.INCOMPLETE_MESSAGE(
                "Required fields not available for Graph message %s", graph.graph_id
            );
        }
        return email;
    }

    public override void set_used_as_custom(bool enabled) {
        Convey.Folder.SpecialUse old_use = this._used_as;
        this._used_as = enabled ? Convey.Folder.SpecialUse.CUSTOM : Convey.Folder.SpecialUse.NONE;
        notify_use_changed(old_use, this._used_as);
    }

    public async void mark_email_async(Gee.Collection<Convey.EmailIdentifier> to_mark,
                                       Convey.EmailFlags? flags_to_add,
                                       Convey.EmailFlags? flags_to_remove,
                                       GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        check_open();
        yield ensure_loaded(cancellable);
        if (flags_to_add == null && flags_to_remove == null) {
            return;
        }
        Gee.HashMap<Convey.EmailIdentifier,Convey.EmailFlags> changed =
            new Gee.HashMap<Convey.EmailIdentifier,Convey.EmailFlags>();
        foreach (Convey.EmailIdentifier id in to_mark) {
            Convey.Graph.EmailIdentifier? graph = id as Convey.Graph.EmailIdentifier;
            if (graph == null) {
                continue;
            }
            Convey.Email? email = this.email_by_id.get(graph.graph_id);
            if (email == null) {
                continue;
            }

            bool? is_read = null;
            bool? is_flagged = null;
            bool? load_remote_images = null;
            if (flags_to_add != null) {
                if (flags_to_add.contains(Convey.EmailFlags.UNREAD)) {
                    is_read = false;
                }
                if (flags_to_add.contains(Convey.EmailFlags.FLAGGED)) {
                    is_flagged = true;
                }
                if (flags_to_add.contains(Convey.EmailFlags.LOAD_REMOTE_IMAGES)) {
                    load_remote_images = true;
                }
            }
            if (flags_to_remove != null) {
                if (flags_to_remove.contains(Convey.EmailFlags.UNREAD)) {
                    is_read = true;
                }
                if (flags_to_remove.contains(Convey.EmailFlags.FLAGGED)) {
                    is_flagged = false;
                }
                if (flags_to_remove.contains(Convey.EmailFlags.LOAD_REMOTE_IMAGES)) {
                    load_remote_images = false;
                }
            }
            if (is_read == null && is_flagged == null && load_remote_images == null) {
                continue;
            }

            Convey.EmailFlags updated = email.email_flags ?? new Convey.EmailFlags();
            if (is_read != null) {
                if (is_read == true) {
                    updated.remove(Convey.EmailFlags.UNREAD);
                } else {
                    updated.add(Convey.EmailFlags.UNREAD);
                }
            }
            if (is_flagged != null) {
                if (is_flagged == true) {
                    updated.add(Convey.EmailFlags.FLAGGED);
                } else {
                    updated.remove(Convey.EmailFlags.FLAGGED);
                }
            }
            if (load_remote_images != null) {
                if (load_remote_images == true) {
                    updated.add(Convey.EmailFlags.LOAD_REMOTE_IMAGES);
                } else {
                    updated.remove(Convey.EmailFlags.LOAD_REMOTE_IMAGES);
                }
            }
            email.set_flags(updated);
            changed.set(email.id, updated);

            Convey.Graph.Client.Message? message = this.message_by_id.get(graph.graph_id);
            if (message != null) {
                if (is_read != null) {
                    message.is_read = (is_read == true);
                }
                if (is_flagged != null) {
                    message.is_flagged = (is_flagged == true);
                }
                if (load_remote_images != null) {
                    message.load_remote_images = (load_remote_images == true);
                }
            }
            this.client.update_message_state.begin(
                graph.graph_id,
                is_read,
                is_flagged,
                cancellable,
                (obj, res) => {
                    try {
                        this.client.update_message_state.end(res);
                    } catch (GLib.Error err) {
                        warning(
                            "Graph update state failed for %s: %s",
                            graph.graph_id,
                            err.message
                        );
                    }
                }
            );
        }

        if (!changed.is_empty) {
            this._properties.set_unread(count_unread());
            notify_email_flags_changed(changed);
            persist_cached_messages();
        }
    }

    public async Convey.Revokable?
        move_email_async(Gee.Collection<Convey.EmailIdentifier> to_move,
                         Convey.FolderPath destination,
                         GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        check_open();
        yield ensure_loaded(cancellable);

        Convey.Graph.Folder destination_folder = get_destination_folder(destination);
        if (destination_folder.path.compare_to(this.path) == 0) {
            return new Convey.Graph.NoopRevokable();
        }

        Gee.ArrayList<Convey.EmailIdentifier> candidates = new Gee.ArrayList<Convey.EmailIdentifier>();
        Gee.ArrayList<string> candidate_ids = new Gee.ArrayList<string>();
        foreach (Convey.EmailIdentifier id in to_move) {
            Convey.Graph.EmailIdentifier? graph = id as Convey.Graph.EmailIdentifier;
            if (graph == null || !this.email_by_id.has_key(graph.graph_id)) {
                continue;
            }
            candidates.add(id);
            candidate_ids.add(graph.graph_id);
        }

        // Show change immediately before the API call completes
        Gee.ArrayList<Convey.EmailIdentifier> removed = remove_cached_emails(candidates);
        if (!removed.is_empty) {
            notify_email_removed(removed);
        }

        // Stamp removed IDs so refresh ignores stale server echoes for a few seconds
        int64 now = GLib.get_monotonic_time();
        this.owner.cancel_active_poll();

        Gee.ArrayList<string> new_ids = new Gee.ArrayList<string>();
        foreach (string graph_id in candidate_ids) {
            this.recently_removed.set(graph_id, now);
            try {
                string new_id = yield this.client.move_message(
                    graph_id,
                    destination_folder.graph_folder_id,
                    cancellable
                );
                if (!String.is_empty(new_id)) {
                    new_ids.add(new_id);
                }
            } catch (GLib.Error err) {
                warning("Graph move failed for %s: %s", graph_id, err.message);
            }
        }

        // Refresh destination async, then trigger full poll when done
        if (destination_folder.is_cache_loaded) {
            destination_folder.refresh_async.begin(true, null, (obj, res) => {
                try {
                    destination_folder.refresh_async.end(res);
                } catch (GLib.IOError.CANCELLED err) {
                } catch (GLib.Error err) {
                    warning("Graph refresh failed for %s: %s",
                        destination_folder.path.to_string(), err.message);
                }
                this.owner.trigger_immediate_poll();
            });
        } else {
            this.owner.trigger_immediate_poll();
        }

        // Return a revokable that can move the messages back to this folder.
        return new Convey.Graph.RevokableMove(
            this.client,
            this.owner,
            new_ids,
            destination_folder,
            this
        );
    }

    public async Convey.Revokable?
        archive_email_async(Gee.Collection<Convey.EmailIdentifier> email_ids,
                            GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        Convey.Graph.Folder? archive =
            this.owner.get_graph_special_folder(Convey.Folder.SpecialUse.ARCHIVE);
        if (archive == null) {
            throw new Convey.EngineError.NOT_FOUND(
                "No archive folder available for Graph account"
            );
        }
        return yield move_email_async(email_ids, archive.path, cancellable);
    }

    public async Convey.EmailIdentifier? create_email_async(
        Convey.RFC822.Message rfc822,
        Convey.EmailFlags? flags,
        GLib.DateTime? date_received,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        check_open();
        string message_id = yield this.client.create_message_in_folder(
            this.folder_id,
            rfc822,
            cancellable
        );
        if (this.is_loaded) {
            yield refresh_async(true, cancellable);
        }
        int64 sort_order = date_received != null
            ? date_received.to_unix()
            : new GLib.DateTime.now_local().to_unix();
        return new Convey.Graph.EmailIdentifier(message_id, sort_order);
    }

    public async void remove_email_async(Gee.Collection<Convey.EmailIdentifier> email_ids,
                                         GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        check_open();
        yield ensure_loaded(cancellable);

        Gee.ArrayList<Convey.EmailIdentifier> to_delete = new Gee.ArrayList<Convey.EmailIdentifier>();
        Gee.ArrayList<string> graph_ids = new Gee.ArrayList<string>();
        foreach (Convey.EmailIdentifier id in email_ids) {
            Convey.Graph.EmailIdentifier? graph = id as Convey.Graph.EmailIdentifier;
            if (graph == null || !this.email_by_id.has_key(graph.graph_id)) {
                continue;
            }
            to_delete.add(id);
            graph_ids.add(graph.graph_id);
        }

        // Show change immediately before API calls complete
        Gee.ArrayList<Convey.EmailIdentifier> removed = remove_cached_emails(to_delete);
        if (removed.is_empty) {
            return;
        }
        notify_email_removed(removed);

        int64 now = GLib.get_monotonic_time();
        this.owner.cancel_active_poll();

        foreach (string graph_id in graph_ids) {
            this.recently_removed.set(graph_id, now);
            try {
                yield this.client.delete_message(graph_id, cancellable);
            } catch (GLib.Error err) {
                warning("Graph delete failed for %s: %s", graph_id, err.message);
            }
        }

        this.owner.trigger_immediate_poll();
    }

    public async void empty_folder_async(GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        check_open();
        yield ensure_loaded(cancellable);

        Gee.ArrayList<Convey.EmailIdentifier> ids = new Gee.ArrayList<Convey.EmailIdentifier>();
        foreach (Convey.Email email in this.email_cache) {
            ids.add(email.id);
        }

        if (!ids.is_empty) {
            yield remove_email_async(ids, cancellable);
        }
    }

    public async void copy_email_async(Gee.Collection<Convey.EmailIdentifier> to_copy,
                                       Convey.FolderPath destination,
                                       GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        check_open();
        yield ensure_loaded(cancellable);
        Convey.Graph.Folder destination_folder = get_destination_folder(destination);
        if (destination_folder.path.compare_to(this.path) == 0) {
            return;
        }
        foreach (Convey.EmailIdentifier id in to_copy) {
            Convey.Graph.EmailIdentifier? graph = id as Convey.Graph.EmailIdentifier;
            if (graph == null || !this.email_by_id.has_key(graph.graph_id)) {
                continue;
            }
            yield this.client.copy_message(
                graph.graph_id,
                destination_folder.graph_folder_id,
                cancellable
            );
        }
        if (destination_folder.is_cache_loaded) {
            yield destination_folder.refresh_async(true, cancellable);
        }
    }

    internal async void refresh_async(bool force, GLib.Cancellable? cancellable)
        throws GLib.Error {
        if (!force && this.is_loaded) {
            return;
        }

        Gee.List<Convey.Graph.Client.Message> messages = yield this.client.list_messages(
            this.folder_id,
            get_refresh_limit(),
            this.owner.information.prefetch_period_days,
            0,
            cancellable
        );
        // Full listing: sweep everything the server no longer reports.
        apply_refresh(messages, new Gee.HashSet<string>(), null);
    }

    /**
     * Incrementally syncs the folder with the server.
     *
     * Modelled on evolution-ews' SyncFolderItems handling, two-phase like
     * its IdOnly + GetItem flow: delta queries are only a change signal
     * (ids), and full messages are fetched separately, because Graph delta
     * entries don't reliably carry message properties. The cursor is
     * persisted with the cache, and server-side cursor invalidation
     * (HTTP 410) re-baselines. Baselines are cheap: $deltaToken=latest
     * grabs a cursor at the current state, then a full listing reconciles
     * the cache — no delta enumeration of the whole folder.
     *
     * When the server rejects delta queries outright, falls back to the
     * newest-first page poll for the rest of the session.
     */
    internal async bool sync_async(GLib.Cancellable? cancellable)
        throws GLib.Error {
        if (this.delta_unsupported) {
            return yield poll_refresh_async(cancellable);
        }
        if (this.sync_running) {
            // Another sync is mid-flight (e.g. the full-sync pass overlapping
            // an immediate poll); running two would race on the cursor.
            debug("Graph: sync already running for %s, skipping",
                this.path.to_string());
            return false;
        }
        this.sync_running = true;
        try {
            return yield delta_sync(cancellable);
        } finally {
            this.sync_running = false;
        }
    }

    private async bool delta_sync(GLib.Cancellable? cancellable)
        throws GLib.Error {
        load_persisted_cache();

        if (String.is_empty(this.delta_link)) {
            yield delta_baseline(cancellable);
            return false;
        }

        Gee.Set<string> changed_ids = new Gee.HashSet<string>();
        Gee.Set<string> removed = new Gee.HashSet<string>();
        string cursor = this.delta_link;
        bool complete = false;
        // Cap the resume loop: a server that never yields a deltaLink must
        // not pin this folder's sync forever (each batch is up to 50 pages).
        // On cap, apply what we have and continue from the last nextLink
        // cursor next tick.
        int batches = 0;
        while (!complete && batches < 5) {
            batches++;
            Convey.Graph.Client.DeltaResult result;
            try {
                result = yield this.client.delta_messages(
                    this.folder_id, cursor, cancellable
                );
            } catch (Convey.Graph.HttpError.BAD_REQUEST err) {
                mark_delta_unsupported(err);
                return yield poll_refresh_async(cancellable);
            } catch (GLib.IOError.CANCELLED err) {
                throw err;
            } catch (GLib.Error err) {
                // Delta failed for a transient reason; keep mail flowing
                // with a full listing and retry the cursor next tick (delta
                // replays are idempotent).
                debug("Graph: delta sync failed for %s, using full " +
                    "listing: %s", this.path.to_string(), err.message);
                yield refresh_async(true, cancellable);
                return false;
            }
            if (result.resync_required) {
                // Cursor invalidated: discard it and re-baseline. The
                // full listing diff-reconciles against the existing
                // cache rather than wiping it.
                this.delta_link = "";
                yield delta_baseline(cancellable);
                return false;
            }
            // A message can be removed in one batch and re-created in a
            // later one (or vice versa); the newest report wins.
            foreach (string id in result.changed_ids) {
                changed_ids.add(id);
                removed.remove(id);
            }
            foreach (string id in result.removed) {
                removed.add(id);
                changed_ids.remove(id);
            }
            cursor = result.delta_link;
            complete = result.complete;
            debug("Graph: delta batch %d for %s: %d changed, %d removed, " +
                "complete=%s", batches, this.path.to_string(),
                result.changed_ids.size, result.removed.size,
                complete.to_string());
        }

        if (changed_ids.size > POLL_BATCH) {
            // Too many changes to fetch one by one; a full listing is
            // cheaper and reconciles removals too. Only consume the cursor
            // once the listing has succeeded, so an interrupted listing
            // replays these changes instead of losing them.
            yield refresh_async(true, cancellable);
            this.delta_link = cursor;
            persist_cached_messages();
            return true;
        }

        // Ignore changes to messages outside the prefetch window (unless
        // already cached): fetching them would add mail the next full
        // listing sweeps away again.
        int64 cutoff_unix = 0;
        int prefetch_days = this.owner.information.prefetch_period_days;
        if (prefetch_days >= 0) {
            cutoff_unix = new GLib.DateTime.now_utc()
                .add_days(0 - prefetch_days)
                .to_unix();
        }

        Gee.ArrayList<Convey.Graph.Client.Message> fetched =
            new Gee.ArrayList<Convey.Graph.Client.Message>();
        foreach (string id in changed_ids) {
            try {
                Convey.Graph.Client.Message message =
                    yield this.client.fetch_message(id, cancellable);
                if (cutoff_unix > 0 &&
                    message.received_at != null &&
                    message.received_at.to_unix() < cutoff_unix &&
                    !this.email_by_id.has_key(id)) {
                    continue;
                }
                fetched.add(message);
            } catch (Convey.Graph.HttpError.NOT_FOUND err) {
                // Deleted between the delta response and now.
                removed.add(id);
            } catch (Convey.Graph.HttpError.GONE err) {
                removed.add(id);
            }
        }
        debug("Graph: delta sync for %s: %d changed, %d removed, %d fetched",
            this.path.to_string(), changed_ids.size, removed.size,
            fetched.size);
        // Set the cursor before applying so the persisted cache and
        // cursor are written as one consistent snapshot; when nothing
        // changed, skip the disk write — the old cursor stays valid.
        this.delta_link = cursor;
        if (!fetched.is_empty || !removed.is_empty) {
            apply_refresh(fetched, null, removed);
            return true;
        }
        return false;
    }

    /**
     * Establishes a delta cursor and reconciles the cache.
     *
     * The cursor is requested first ($deltatoken=latest, no enumeration),
     * then the full listing runs; anything changing in between is covered
     * by the next delta call, so there is no race window. If the server
     * won't hand out a usable cursor, delta is marked unsupported rather
     * than re-running a full listing every tick.
     */
    private async void delta_baseline(GLib.Cancellable? cancellable)
        throws GLib.Error {
        // Cold-cache path: a cursor request plus a full listing. On a large
        // folder this is the slowest thing the backend does, and it holds
        // sync_running for its whole duration, so say when it starts.
        debug("Graph: establishing delta baseline for %s",
            this.path.to_string());
        Convey.Graph.Client.DeltaResult token;
        try {
            token = yield this.client.delta_messages(
                this.folder_id, null, cancellable
            );
        } catch (Convey.Graph.HttpError.BAD_REQUEST err) {
            mark_delta_unsupported(err);
            yield refresh_async(true, cancellable);
            return;
        } catch (GLib.IOError.CANCELLED err) {
            throw err;
        } catch (GLib.Error err) {
            // Whatever went wrong with the token request, mail must keep
            // flowing: full listing now, retry the baseline next tick.
            debug("Graph: delta baseline failed for %s, using full " +
                "listing: %s", this.path.to_string(), err.message);
            yield refresh_async(true, cancellable);
            return;
        }
        if (token.resync_required || String.is_empty(token.delta_link)) {
            mark_delta_unsupported(null);
            yield refresh_async(true, cancellable);
            return;
        }
        yield refresh_async(true, cancellable);
        this.delta_link = token.delta_link;
        persist_cached_messages();
        debug("Graph: delta baseline established for %s",
            this.path.to_string());
    }

    private void mark_delta_unsupported(GLib.Error? err) {
        debug("Graph: delta sync unsupported for %s, falling back to " +
            "page polling: %s", this.path.to_string(),
            err != null ? err.message : "no usable cursor");
        this.delta_unsupported = true;
    }

    /**
     * Cheap new-mail check; fallback when delta queries are unsupported.
     *
     * Fetches messages newest-first in small pages, stopping as soon as a
     * page reaches messages older than the newest cached one, and applies
     * them without removing anything from the cache. Flag changes on older
     * mail and removals are reconciled by full listings: folder opens and
     * the account's periodic full-sync pass, which uses refresh_async for
     * delta-unsupported folders.
     */
    internal async bool poll_refresh_async(GLib.Cancellable? cancellable)
        throws GLib.Error {
        int64 newest = newest_cached_unix();
        if (!this.is_loaded || newest == 0) {
            yield refresh_async(true, cancellable);
            return false;
        }
        Gee.List<Convey.Graph.Client.Message> messages = yield this.client.list_messages(
            this.folder_id,
            POLL_BATCH,
            this.owner.information.prefetch_period_days,
            newest,
            cancellable
        );
        if (messages.is_empty) {
            return false;
        }
        apply_refresh(messages, null, null);
        return true;
    }

    private int64 newest_cached_unix() {
        int64 newest = 0;
        foreach (Convey.Email cached_email in this.email_cache) {
            Convey.Graph.EmailIdentifier? graph_id = cached_email.id as Convey.Graph.EmailIdentifier;
            if (graph_id != null && graph_id.sort_order > newest) {
                newest = graph_id.sort_order;
            }
        }
        return newest;
    }

    /**
     * Reconciles server messages into the local cache.
     *
     * When sweep_keep is non-null, any cached message in neither messages
     * nor sweep_keep is removed (full reconcile). Otherwise only the ids in
     * deleted_ids, if any, are removed.
     */
    private void apply_refresh(Gee.List<Convey.Graph.Client.Message> messages,
                               Gee.Set<string>? sweep_keep,
                               Gee.Set<string>? deleted_ids) {
        bool had_loaded = this.is_loaded;
        int previous_total = this._properties.email_total;
        Gee.Set<string> refreshed_ids = new Gee.HashSet<string>();
        Gee.ArrayList<Convey.EmailIdentifier> appended = new Gee.ArrayList<Convey.EmailIdentifier>();
        Gee.ArrayList<Convey.EmailIdentifier> inserted = new Gee.ArrayList<Convey.EmailIdentifier>();
        Gee.ArrayList<Convey.EmailIdentifier> removed = new Gee.ArrayList<Convey.EmailIdentifier>();
        Gee.HashMap<Convey.EmailIdentifier, Convey.EmailFlags> flags_changed =
            new Gee.HashMap<Convey.EmailIdentifier, Convey.EmailFlags>();

        int64 newest_cached_timestamp = had_loaded ? newest_cached_unix() : 0;

        // Expire stale tombstones before processing the response
        if (!this.recently_removed.is_empty) {
            int64 refresh_now = GLib.get_monotonic_time();
            Gee.ArrayList<string> expired = new Gee.ArrayList<string>();
            foreach (var entry in this.recently_removed.entries) {
                if (refresh_now - entry.value >= REMOVED_GRACE_USEC) {
                    expired.add(entry.key);
                }
            }
            foreach (string id in expired) {
                this.recently_removed.unset(id);
            }
        }

        foreach (Convey.Graph.Client.Message message in messages) {
            if (String.is_empty(message.id)) {
                continue;
            }
            // Suppress stale server echoes for messages removed in the last few seconds
            if (this.recently_removed.has_key(message.id)) {
                continue;
            }
            refreshed_ids.add(message.id);
            Convey.Email? existing = this.email_by_id.get(message.id);
            Convey.EmailFlags? old_flags = null;
            if (existing != null && existing.email_flags != null) {
                old_flags = new Convey.EmailFlags();
                old_flags.add_all(existing.email_flags);
            }

            Convey.Email email = build_email(message, existing);
            if (existing == null) {
                this.email_cache.add(email);

                // Determine if this is a new email (appended) or old email (inserted)
                if (had_loaded) {
                    int64 email_timestamp = message.received_at != null
                        ? message.received_at.to_unix()
                        : 0;
                    if (email_timestamp > newest_cached_timestamp) {
                        // New email - should be appended to the top of the vector
                        appended.add(email.id);
                    } else {
                        // Old email being backfilled - should be inserted
                        inserted.add(email.id);
                    }
                } else {
                    // First load - all emails are inserted (old), no notifications
                    inserted.add(email.id);
                }
            } else if (old_flags != null && email.email_flags != null) {
                if (!old_flags.equal_to(email.email_flags)) {
                    flags_changed.set(email.id, email.email_flags);
                }
            }
            this.email_by_id.set(message.id, email);
            this.message_by_id.set(message.id, message);
        }
        if (had_loaded && (sweep_keep != null || deleted_ids != null)) {
            Gee.ArrayList<string> stale_ids = new Gee.ArrayList<string>();
            if (sweep_keep != null) {
                foreach (string cached_id in this.email_by_id.keys) {
                    if (refreshed_ids.contains(cached_id) ||
                        sweep_keep.contains(cached_id)) {
                        continue;
                    }
                    stale_ids.add(cached_id);
                }
            } else {
                foreach (string deleted_id in deleted_ids) {
                    if (this.email_by_id.has_key(deleted_id)) {
                        stale_ids.add(deleted_id);
                    }
                }
            }
            foreach (string cached_id in stale_ids) {
                Convey.Email? cached = this.email_by_id.get(cached_id);
                if (cached != null) {
                    this.email_cache.remove(cached);
                    removed.add(cached.id);
                }
                this.email_by_id.unset(cached_id);
                this.message_by_id.unset(cached_id);
            }
        }

        sort_email_cache();
        this._properties.set_total(this.email_cache.size);
        this._properties.set_unread(count_unread());
        if (this._properties.email_total != previous_total) {
            Convey.Folder.CountChangeReason reason =
                this._properties.email_total > previous_total
                ? Convey.Folder.CountChangeReason.INSERTED
                : Convey.Folder.CountChangeReason.REMOVED;
            notify_email_count_changed(this._properties.email_total, reason);
        }

        // Notify appended first (new emails that trigger notifications)
        if (!appended.is_empty) {
            notify_email_appended(appended);
            notify_email_locally_appended(appended);
        }

        // Then notify inserted (old backfilled emails, no notifications)
        if (!inserted.is_empty) {
            notify_email_inserted(inserted);
        }
        
        var complete = new Gee.LinkedList<Convey.EmailIdentifier>();
        complete.add_all(appended);
        complete.add_all(inserted);
        if (!complete.is_empty) {
            notify_email_locally_complete(complete);
        }


        if (!flags_changed.is_empty) {
            notify_email_flags_changed(flags_changed);
        }

        if (!removed.is_empty) {
            notify_email_removed(removed);
        }
        persist_cached_messages();
        this.is_loaded = true;
    }

    internal async bool has_identifier_async(Convey.EmailIdentifier id,
                                             GLib.Cancellable? cancellable)
        throws GLib.Error {
        yield ensure_loaded(cancellable);
        return has_cached_identifier(id);
    }

    internal bool has_cached_identifier(Convey.EmailIdentifier id) {
        Convey.Graph.EmailIdentifier? graph = id as Convey.Graph.EmailIdentifier;
        return graph != null && this.email_by_id.has_key(graph.graph_id);
    }

    internal Gee.Collection<Convey.Email> list_cached_emails() {
        return this.email_cache.read_only_view;
    }

    private Convey.Graph.Folder get_destination_folder(Convey.FolderPath destination)
        throws GLib.Error {
        Convey.Graph.Folder? folder = this.owner.get_graph_folder(destination);
        if (folder == null) {
            throw new Convey.EngineError.NOT_FOUND(
                "Unknown Graph folder: %s",
                destination.to_string()
            );
        }
        return folder;
    }

    private Gee.ArrayList<Convey.EmailIdentifier>
        remove_cached_emails(Gee.Collection<Convey.EmailIdentifier> ids) {
        int previous_total = this._properties.email_total;
        Gee.ArrayList<Convey.EmailIdentifier> removed = new Gee.ArrayList<Convey.EmailIdentifier>();
        foreach (Convey.EmailIdentifier id in ids) {
            Convey.Graph.EmailIdentifier? graph = id as Convey.Graph.EmailIdentifier;
            if (graph == null) {
                continue;
            }
            Convey.Email? email = this.email_by_id.get(graph.graph_id);
            if (email == null) {
                continue;
            }
            this.email_cache.remove(email);
            this.email_by_id.unset(graph.graph_id);
            this.message_by_id.unset(graph.graph_id);
            removed.add(id);
        }
        if (!removed.is_empty) {
            this._properties.set_total(this.email_cache.size);
            this._properties.set_unread(count_unread());
            if (this._properties.email_total != previous_total) {
                notify_email_count_changed(
                    this._properties.email_total,
                    Convey.Folder.CountChangeReason.REMOVED
                );
            }
            persist_cached_messages();
        }
        return removed;
    }

    private int count_unread() {
        int unread = 0;
        foreach (Convey.Email email in this.email_cache) {
            if (email.email_flags != null && email.email_flags.is_unread()) {
                unread++;
            }
        }
        return unread;
    }

    private async void ensure_loaded(GLib.Cancellable? cancellable)
        throws GLib.Error {
        if (!this.is_loaded) {
            yield refresh_async(true, cancellable);
        }
    }

    private Convey.Email build_email(Convey.Graph.Client.Message message,
                                    Convey.Email? existing = null) {
        Convey.Email email = existing ?? new Convey.Email(
            new Convey.Graph.EmailIdentifier(
                message.id,
                message.received_at != null ? message.received_at.to_unix() : 0
            )
        );

        // Ensure the Graph client Message preserves any local LOAD_REMOTE_IMAGES
        // preference so it is written back into the cache. The API does not
        // support this flag, so retain it from the cached existing email.
        if (!message.load_remote_images && existing != null && existing.email_flags != null &&
            existing.email_flags.contains(Convey.EmailFlags.LOAD_REMOTE_IMAGES)) {
            message.load_remote_images = true;
        }

        if (message.received_at != null) {
            email.set_send_date(new Convey.RFC822.Date(message.received_at));
        }
        Convey.RFC822.MailboxAddresses? from = message.from;
        if (from == null || from.is_empty) {
            from = new Convey.RFC822.MailboxAddresses.single(
                this.owner.information.primary_mailbox
            );
        }
        Convey.RFC822.MailboxAddresses to =
            message.to ?? new Convey.RFC822.MailboxAddresses();
        Convey.RFC822.MailboxAddresses cc =
            message.cc ?? new Convey.RFC822.MailboxAddresses();
        Convey.RFC822.MailboxAddresses bcc =
            message.bcc ?? new Convey.RFC822.MailboxAddresses();
        try {
            email.set_originators(from, null, null);
        } catch (GLib.Error err) {
            debug("Error setting Graph originators: %s", err.message);
        }
        email.set_receivers(to, cc, bcc);

        Convey.RFC822.MessageID? message_id = build_message_id(message);
        Convey.RFC822.MessageIDList? references = build_conversation_references(message);
        if (message_id != null || references != null) {
            email.set_full_references(message_id, null, references);
        }

        email.set_message_subject(new Convey.RFC822.Subject(message.subject));
        email.set_message_preview(
            new Convey.RFC822.PreviewText.from_string(message.body_preview)
        );

        var flags = new Convey.EmailFlags();
        if (!message.is_read) {
            flags.add(Convey.EmailFlags.UNREAD);
        }
        if (message.is_flagged) {
            flags.add(Convey.EmailFlags.FLAGGED);
        }
        // Preserve the LOAD_REMOTE_IMAGES flag from the Graph message if set,
        // otherwise preserve the existing cached flag if present.
        if (message.load_remote_images) {
            flags.add(Convey.EmailFlags.LOAD_REMOTE_IMAGES);
        } else if (existing != null && existing.email_flags != null &&
                   existing.email_flags.contains(Convey.EmailFlags.LOAD_REMOTE_IMAGES)) {
            flags.add(Convey.EmailFlags.LOAD_REMOTE_IMAGES);
        }
        email.set_flags(flags);

        GLib.DateTime received = message.received_at ?? new GLib.DateTime.now_local();
        email.set_email_properties(new Convey.Graph.EmailProperties(received, message.size));

        if (message.body != null) {
            string body = message.body;
            email.set_message_body(new Convey.RFC822.Text(new Convey.Memory.StringBuffer(body)));
            Convey.RFC822.Header? header = build_header(message);
            if (header != null) {
                email.set_message_header(header);
            }
        }

        return email;
    }

    private Convey.RFC822.Header? build_header(Convey.Graph.Client.Message message) {
        Convey.RFC822.Date sent = new Convey.RFC822.Date(
            message.received_at ?? new GLib.DateTime.now_local()
        );
        string header = "";
        if (message.from != null) {
            header += "From: %s\r\n".printf(message.from.to_rfc822_string());
        }
        if (message.to != null) {
            header += "To: %s\r\n".printf(message.to.to_rfc822_string());
        }
        if (message.cc != null) {
            header += "Cc: %s\r\n".printf(message.cc.to_rfc822_string());
        }
        if (!String.is_empty(message.subject)) {
            header += "Subject: %s\r\n".printf(new Convey.RFC822.Subject(message.subject).to_rfc822_string());
        }
        Convey.RFC822.MessageID? message_id = build_message_id(message);
        if (message_id != null) {
            header += "Message-Id: %s\r\n".printf(message_id.to_rfc822_string());
        }
        Convey.RFC822.MessageIDList? references = build_conversation_references(message);
        if (references != null) {
            header += "References: %s\r\n".printf(references.to_rfc822_string());
        }
        header += "MIME-Version: 1.0\r\n";
        if (message.body_content_type.down() == "html") {
            header += "Content-Type: text/html; charset=UTF-8\r\n";
        } else {
            header += "Content-Type: text/plain; charset=UTF-8\r\n";
        }
        header += "Content-Transfer-Encoding: 8bit\r\n";
        header += "Date: %s\r\n\r\n".printf(sent.to_rfc822_string());

        try {
            return new Convey.RFC822.Header(new Convey.Memory.StringBuffer(header));
        } catch (Convey.RFC822.Error err) {
            debug("Could not build Graph headers: %s", err.message);
        }
        return null;
    }

    private int get_refresh_limit() {
        int prefetch_days = this.owner.information.prefetch_period_days;
        if (prefetch_days <= 0) {
            return MAX_REFRESH_BATCH;
        }
        return int.max(MIN_REFRESH_BATCH, int.min(MAX_REFRESH_BATCH, prefetch_days * 20));
    }

    private void populate_full_message(Convey.Email email,
                                       Convey.Memory.Buffer full_rfc822,
                                       string graph_message_id) {
        Convey.RFC822.Message parsed;
        try {
            parsed = new Convey.RFC822.Message.from_buffer(full_rfc822);
        } catch (Convey.RFC822.Error err) {
            debug("Error parsing Graph RFC822 payload: %s", err.message);
            return;
        }

        email.set_message_header(parsed.get_header());
        email.set_message_body(parsed.get_body());
        string preview = parsed.get_preview();
        if (!String.is_empty(preview)) {
            email.set_message_preview(
                new Convey.RFC822.PreviewText.from_string(preview)
            );
        }

        if (email.attachments.is_empty) {
            populate_attachments(email, parsed, graph_message_id);
        }
    }

    private void populate_attachments(Convey.Email email,
                                      Convey.RFC822.Message parsed,
                                      string graph_message_id) {
        Gee.List<Convey.RFC822.Part> parts;
        try {
            parts = parsed.get_attachments();
        } catch (Convey.RFC822.Error err) {
            debug("Error listing Graph attachments: %s", err.message);
            return;
        }
        if (parts.is_empty) {
            return;
        }

        string? attachment_dir = compute_attachment_path(graph_message_id);
        if (String.is_empty(attachment_dir)) {
            return;
        }
        GLib.DirUtils.create_with_parents(attachment_dir, 0700);

        int index = 0;
        foreach (Convey.RFC822.Part part in parts) {
            index++;
            string? filename = part.get_clean_filename();
            if (String.is_empty(filename)) {
                filename = "attachment-%d".printf(index);
            }
            string path = GLib.Path.build_filename(
                attachment_dir,
                "%03d-%s".printf(index, (string) filename)
            );
            try {
                Convey.Memory.Buffer content = part.write_to_buffer(
                    Convey.RFC822.Part.EncodingConversion.NONE
                );
                GLib.File file = GLib.File.new_for_path(path);
                file.replace_contents(
                    content.get_bytes().get_data(),
                    null,
                    false,
                    GLib.FileCreateFlags.NONE,
                    null
                );
                email.add_attachment(
                    new Convey.Graph.Attachment.from_part(
                        part,
                        file,
                        (int64) content.size
                    )
                );
            } catch (GLib.Error err) {
                warning("Error persisting Graph attachment %s: %s", path, err.message);
            }
        }
    }

    private void sort_email_cache() {
        this.email_cache.sort((a, b) => b.id.natural_sort_comparator(a.id));
    }

    private Convey.RFC822.MessageIDList? build_conversation_references(
        Convey.Graph.Client.Message message
    ) {
        if (String.is_empty(message.conversation_id)) {
            return null;
        }
        string conversation_hash = GLib.Checksum.compute_for_string(
            GLib.ChecksumType.SHA1,
            message.conversation_id
        );
        Convey.RFC822.MessageID conversation_id = new Convey.RFC822.MessageID(
            "graph-conversation-%s@convey.local".printf(conversation_hash)
        );
        return new Convey.RFC822.MessageIDList.single(conversation_id);
    }

    private Convey.RFC822.MessageID? build_message_id(Convey.Graph.Client.Message message) {
        if (!String.is_empty(message.internet_message_id)) {
            try {
                return new Convey.RFC822.MessageID.from_rfc822_string(
                    message.internet_message_id
                );
            } catch (Convey.RFC822.Error err) {
                debug("Error parsing Graph message-id: %s", err.message);
            }
        }
        if (String.is_empty(message.id)) {
            return null;
        }
        return new Convey.RFC822.MessageID("graph-%s@convey.local".printf(message.id));
    }

    private string? compute_cache_path() {
        GLib.File? data_dir = this.owner.information.data_dir;
        // Fallback to the user's data dir if account data_dir isn't set yet.
        if (data_dir == null) {
            // Fallback to ~/.local/share/convey if account data_dir isn't set.
            string fallback = GLib.Path.build_filename(Environment.get_home_dir(), ".local", "share", "convey");
            data_dir = GLib.File.new_for_path(fallback);
        }
        string folder_hash = GLib.Checksum.compute_for_string(
            GLib.ChecksumType.SHA1,
            this.folder_id
        );
        GLib.File cache_file = data_dir.get_child("graph-cache").get_child(
            "%s.json".printf(folder_hash)
        );
        return cache_file.get_path();
    }

    private string? compute_attachment_path(string graph_message_id) {
        GLib.File? data_dir = this.owner.information.data_dir;
        if (data_dir == null || String.is_empty(graph_message_id)) {
            return null;
        }
        string message_hash = GLib.Checksum.compute_for_string(
            GLib.ChecksumType.SHA1,
            graph_message_id
        );
        GLib.File attachment_dir = data_dir
            .get_child("graph-attachments")
            .get_child(message_hash);
        return attachment_dir.get_path();
    }

    private void load_cached_messages() {
        if (String.is_empty(this.cache_path) ||
            !GLib.FileUtils.test(this.cache_path, GLib.FileTest.EXISTS)) {
            return;
        }
        try {
            string contents;
            size_t contents_length;
            GLib.FileUtils.get_contents(
                this.cache_path,
                out contents,
                out contents_length
            );
            Json.Parser parser = new Json.Parser();
            parser.load_from_data(contents, (ssize_t) contents_length);
            Json.Node? root_node = parser.get_root();
            if (root_node == null || root_node.get_node_type() != Json.NodeType.OBJECT) {
                return;
            }
            Json.Object root = root_node.get_object();
            if (!root.has_member("messages") ||
                root.get_member("messages").get_node_type() != Json.NodeType.ARRAY) {
                return;
            }

            Json.Array messages = root.get_array_member("messages");
            this.email_cache.clear();
            this.email_by_id.clear();
            this.message_by_id.clear();
            // The delta cursor is stored with the messages so the pair is
            // always a consistent snapshot.
            this.delta_link = Client.get_string_member(root, "deltaLink") ?? "";
            for (uint i = 0; i < messages.get_length(); i++) {
                Json.Node item = messages.get_element(i);
                if (item.get_node_type() != Json.NodeType.OBJECT) {
                    continue;
                }
                Convey.Graph.Client.Message parsed = parse_cached_message(
                    messages.get_object_element(i)
                );
                if (String.is_empty(parsed.id)) {
                    continue;
                }
                Convey.Email email = build_email(parsed);
                this.email_cache.add(email);
                this.email_by_id.set(parsed.id, email);
                this.message_by_id.set(parsed.id, parsed);
            }
            sort_email_cache();
            this._properties.set_total(this.email_cache.size);
            this._properties.set_unread(count_unread());
            this.is_loaded = true;
        } catch (GLib.Error err) {
            warning("Error loading Graph cache for %s: %s", this.path.to_string(), err.message);
        }
    }

    private void persist_cached_messages() {
        if (String.is_empty(this.cache_path)) {
            return;
        }
        try {
            string cache_dir = GLib.Path.get_dirname(this.cache_path);
            GLib.DirUtils.create_with_parents(cache_dir, 0700);

            Json.Builder builder = new Json.Builder();
            builder.begin_object();
            builder.set_member_name("deltaLink");
            builder.add_string_value(this.delta_link);
            builder.set_member_name("messages");
            builder.begin_array();
            foreach (Convey.Email email in this.email_cache) {
                Convey.Graph.EmailIdentifier? graph_id = email.id as Convey.Graph.EmailIdentifier;
                if (graph_id == null) {
                    continue;
                }
                Convey.Graph.Client.Message? message = this.message_by_id.get(graph_id.graph_id);
                if (message == null) {
                    continue;
                }
                append_cached_message(builder, message);
            }
            builder.end_array();
            builder.end_object();

            Json.Node root = builder.get_root();
            Json.Generator generator = new Json.Generator();
            generator.set_root(root);
            string payload = generator.to_data(null);
            GLib.FileUtils.set_contents(this.cache_path, payload);
        } catch (GLib.Error err) {
            warning("Error persisting Graph cache for %s: %s", this.path.to_string(), err.message);
        }
    }

    private static Convey.Graph.Client.Message parse_cached_message(Json.Object object) {
        Convey.Graph.Client.Message parsed = new Convey.Graph.Client.Message();
        parsed.id = Client.get_string_member(object, "id") ?? "";
        parsed.conversation_id = Client.get_string_member(object, "conversationId") ?? "";
        parsed.subject = Client.get_string_member(object, "subject") ?? "";
        parsed.internet_message_id = Client.get_string_member(object, "internetMessageId") ?? "";
        parsed.body_preview = Client.get_string_member(object, "bodyPreview") ?? "";
        parsed.body = Client.get_string_member(object, "body");
        parsed.body_content_type = Client.get_string_member(object, "bodyContentType") ?? "text";
        parsed.is_read = Client.get_bool_member(object, "isRead", true);
        parsed.is_flagged = Client.get_bool_member(object, "isFlagged", false);
        parsed.load_remote_images = Client.get_bool_member(object, "loadRemoteImages", false);
        parsed.received_at = Client.parse_datetime(Client.get_string_member(object, "receivedDateTime"));
        parsed.size = Client.get_int_member(object, "size", 0);
        parsed.from = parse_addresses_member(object, "from");
        parsed.to = parse_addresses_member(object, "to");
        parsed.cc = parse_addresses_member(object, "cc");
        parsed.bcc = parse_addresses_member(object, "bcc");
        return parsed;
    }

    private static void append_cached_message(Json.Builder builder,
                                              Convey.Graph.Client.Message message) {
        builder.begin_object();
        set_string_member(builder, "id", message.id);
        set_string_member(builder, "conversationId", message.conversation_id);
        set_string_member(builder, "subject", message.subject);
        set_string_member(builder, "internetMessageId", message.internet_message_id);
        set_string_member(builder, "bodyPreview", message.body_preview);
        if (message.body != null) {
            set_string_member(builder, "body", message.body);
        }
        set_string_member(builder, "bodyContentType", message.body_content_type);
        set_string_member(builder, "from", to_rfc822_string(message.from));
        set_string_member(builder, "to", to_rfc822_string(message.to));
        set_string_member(builder, "cc", to_rfc822_string(message.cc));
        set_string_member(builder, "bcc", to_rfc822_string(message.bcc));
        builder.set_member_name("isRead");
        builder.add_boolean_value(message.is_read);
        builder.set_member_name("isFlagged");
        builder.add_boolean_value(message.is_flagged);
        builder.set_member_name("loadRemoteImages");
        builder.add_boolean_value(message.load_remote_images);
        if (message.received_at != null) {
            set_string_member(
                builder,
                "receivedDateTime",
                message.received_at.format("%Y-%m-%dT%H:%M:%SZ")
            );
        }
        builder.set_member_name("size");
        builder.add_int_value(message.size);
        builder.end_object();
    }

    private static string? to_rfc822_string(Convey.RFC822.MailboxAddresses? addresses) {
        return (addresses == null || addresses.is_empty)
            ? null
            : addresses.to_rfc822_string();
    }

    private static Convey.RFC822.MailboxAddresses? parse_addresses_member(Json.Object object,
                                                                          string key) {
        string? value = Client.get_string_member(object, key);
        if (String.is_empty(value)) {
            return null;
        }
        try {
            return new Convey.RFC822.MailboxAddresses.from_rfc822_string(value);
        } catch (Convey.RFC822.Error err) {
        }
        return null;
    }

    private static void set_string_member(Json.Builder builder, string key, string? value) {
        if (String.is_empty(value)) {
            return;
        }
        builder.set_member_name(key);
        builder.add_string_value(value);
    }

    private static int find_index(Gee.List<Convey.Email> emails, Convey.EmailIdentifier id) {
        for (int i = 0; i < emails.size; i++) {
            if (emails[i].id.equal_to(id)) {
                return i;
            }
        }
        return -1;
    }

}

internal class Convey.Graph.NoopRevokable : Convey.Revokable {

    protected override async void internal_revoke_async(GLib.Cancellable? cancellable)
        throws GLib.Error {
        set_invalid();
        notify_revoked();
    }

    protected override async void internal_commit_async(GLib.Cancellable? cancellable)
        throws GLib.Error {
        set_invalid();
        notify_committed(null);
    }

}

/**
 * A {@link Convey.Revokable} for Graph API move operations.
 *
 * Because the Graph API move is executed immediately (unlike IMAP which can
 * delay the move), this revokable is already in the "committed" state from
 * the moment it is created.  Calling commit_async() signals that the operation
 * is finalised and returns a new RevokableMove pointing back in the other
 * direction so the caller can still undo.  Calling revoke_async() moves the
 * messages back to the original source folder straight away.
 */
internal class Convey.Graph.RevokableMove : Convey.Revokable {

    // The Graph API client used to issue move calls.
    private Convey.Graph.Client client;

    // The account, used to look up folders by path after a move.
    private Convey.Graph.Account account;

    // The Graph message IDs that now live in `current_folder` and should be
    // moved back to `return_folder` when the user hits Undo.
    private Gee.ArrayList<string> message_ids;

    // The folder that currently holds the messages (i.e. the destination of
    // the original move, or the source of the next reverse move).
    private Convey.Graph.Folder current_folder;

    // The folder the messages should be moved back to on revoke.
    private Convey.Graph.Folder return_folder;


    internal RevokableMove(Convey.Graph.Client client,
                           Convey.Graph.Account account,
                           Gee.ArrayList<string> message_ids,
                           Convey.Graph.Folder current_folder,
                           Convey.Graph.Folder return_folder) {
        this.client = client;
        this.account = account;
        this.message_ids = message_ids;
        this.current_folder = current_folder;
        this.return_folder = return_folder;
    }

    protected override async void internal_revoke_async(GLib.Cancellable? cancellable)
        throws GLib.Error {
        // Move every message back to where it came from.
        Gee.ArrayList<string> reverted_ids = new Gee.ArrayList<string>();
        foreach (string id in this.message_ids) {
            try {
                string new_id = yield this.client.move_message(
                    id,
                    this.return_folder.graph_folder_id,
                    cancellable
                );
                if (!String.is_empty(new_id)) {
                    reverted_ids.add(new_id);
                }
            } catch (GLib.Error err) {
                warning(
                    "Graph revoke-move failed for %s: %s",
                    id,
                    err.message
                );
            }
        }

        // Refresh both folders so the UI reflects the new state.
        if (this.current_folder.is_cache_loaded) {
            this.current_folder.refresh_async.begin(
                true, cancellable, (obj, res) => {
                    try {
                        this.current_folder.refresh_async.end(res);
                    } catch (GLib.Error err) {
                        warning(
                            "Graph refresh failed for %s: %s",
                            this.current_folder.path.to_string(),
                            err.message
                        );
                    }
                }
            );
        }
        if (this.return_folder.is_cache_loaded) {
            this.return_folder.refresh_async.begin(
                true, cancellable, (obj, res) => {
                    try {
                        this.return_folder.refresh_async.end(res);
                    } catch (GLib.Error err) {
                        warning(
                            "Graph refresh failed for %s: %s",
                            this.return_folder.path.to_string(),
                            err.message
                        );
                    }
                }
            );
        }

        this.account.trigger_immediate_poll();
        notify_revoked();
        set_invalid();
    }

    protected override async void internal_commit_async(GLib.Cancellable? cancellable)
        throws GLib.Error {
        // The actual API move already happened; committing just means we hand
        // back a new revokable that points in the reverse direction so the
        // caller can still undo after the commit.
        Convey.Graph.RevokableMove reverse = new Convey.Graph.RevokableMove(
            this.client,
            this.account,
            this.message_ids,
            this.current_folder,
            this.return_folder
        );
        notify_committed(reverse);
        set_invalid();
    }

}
