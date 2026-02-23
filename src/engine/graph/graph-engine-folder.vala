/*
 * Copyright 2026 Daniel Elia <d.elia@outlook.com>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

internal class Geary.Graph.Folder : Geary.AbstractLocalFolder,
    Geary.FolderSupport.Mark,
    Geary.FolderSupport.Move,
    Geary.FolderSupport.Archive,
    Geary.FolderSupport.Remove,
    Geary.FolderSupport.Copy {

    private const int MIN_REFRESH_BATCH = 25;
    private const int MAX_REFRESH_BATCH = 500;

    private Geary.Graph.Account owner;
    private Geary.Graph.Client client;
    private Geary.Graph.FolderProperties _properties =
        new Geary.Graph.FolderProperties(0, 0);
    private Geary.FolderPath _path;
    private Geary.Folder.SpecialUse _used_as;
    private string folder_id;

    private Gee.ArrayList<Geary.Email> email_cache =
        new Gee.ArrayList<Geary.Email>();
    private Gee.HashMap<string,Geary.Email> email_by_id =
        new Gee.HashMap<string,Geary.Email>();
    private Gee.HashMap<string,Geary.Graph.Client.Message> message_by_id =
        new Gee.HashMap<string,Geary.Graph.Client.Message>();
    private bool is_loaded = false;
    private string? cache_path = null;


    public override Geary.Account account { get { return this.owner; } }
    public override Geary.FolderProperties properties { get { return this._properties; } }
    public override Geary.FolderPath path { get { return this._path; } }
    public override Geary.Folder.SpecialUse used_as { get { return this._used_as; } }
    internal bool is_cache_loaded { get { return this.is_loaded; } }
    internal string graph_folder_id { get { return this.folder_id; } }


    public Folder(Geary.Graph.Account owner,
                  Geary.Graph.Client client,
                  Geary.FolderPath path,
                  string folder_id,
                  Geary.Folder.SpecialUse used_as) {
        this.owner = owner;
        this.client = client;
        this._path = path;
        this.folder_id = folder_id;
        this._used_as = used_as;
        this.cache_path = compute_cache_path();
    }

    public override async bool open_async(Geary.Folder.OpenFlags open_flags,
                                          GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        bool opened = yield base.open_async(open_flags, cancellable);
        if (opened) {
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

    public override async Gee.Collection<Geary.EmailIdentifier> contains_identifiers(
        Gee.Collection<Geary.EmailIdentifier> ids,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        check_open();
        yield ensure_loaded(cancellable);

        Gee.HashSet<Geary.EmailIdentifier> contained = new Gee.HashSet<Geary.EmailIdentifier>();
        foreach (Geary.EmailIdentifier id in ids) {
            Geary.Graph.EmailIdentifier? graph = id as Geary.Graph.EmailIdentifier;
            if (graph != null && this.email_by_id.has_key(graph.graph_id)) {
                contained.add(id);
            }
        }
        return contained;
    }

    public override async Gee.List<Geary.Email>? list_email_by_id_async(
        Geary.EmailIdentifier? initial_id,
        int count,
        Geary.Email.Field required_fields,
        Geary.Folder.ListFlags flags,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        check_open();
        if (count <= 0) {
            return new Gee.ArrayList<Geary.Email>();
        }
        if (flags.is_force_update()) {
            yield refresh_async(true, cancellable);
        } else {
            yield ensure_loaded(cancellable);
        }

        Gee.ArrayList<Geary.Email> ordered = new Gee.ArrayList<Geary.Email>();
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
                throw new Geary.EngineError.NOT_FOUND(
                    "Unknown email identifier: %s", initial_id.to_string()
                );
            }
        }

        Gee.ArrayList<Geary.Email> listed = new Gee.ArrayList<Geary.Email>();
        for (int i = start; i < ordered.size && listed.size < count; i++) {
            Geary.Email email = ordered[i];
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

    public override async Gee.List<Geary.Email>? list_email_by_sparse_id_async(
        Gee.Collection<Geary.EmailIdentifier> ids,
        Geary.Email.Field required_fields,
        Geary.Folder.ListFlags flags,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        if (is_open()) {
            if (flags.is_force_update()) {
                yield refresh_async(true, cancellable);
            } else {
                yield ensure_loaded(cancellable);
            }
        } else if (flags.is_force_update() || !this.is_loaded) {
            throw new Geary.EngineError.OPEN_REQUIRED("%s not open", to_string());
        }

        Gee.ArrayList<Geary.Email> listed = new Gee.ArrayList<Geary.Email>();
        foreach (Geary.EmailIdentifier id in ids) {
            Geary.Graph.EmailIdentifier? graph = id as Geary.Graph.EmailIdentifier;
            if (graph == null) {
                continue;
            }
            Geary.Email? email = this.email_by_id.get(graph.graph_id);
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

    public override async Geary.Email fetch_email_async(
        Geary.EmailIdentifier id,
        Geary.Email.Field required_fields,
        Geary.Folder.ListFlags flags,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        bool is_open_now = is_open();
        if (is_open_now) {
            yield ensure_loaded(cancellable);
        } else if (!this.is_loaded) {
            throw new Geary.EngineError.OPEN_REQUIRED("%s not open", to_string());
        }

        Geary.Graph.EmailIdentifier? graph = id as Geary.Graph.EmailIdentifier;
        if (graph == null) {
            throw new Geary.EngineError.BAD_PARAMETERS(
                "Not a Graph email identifier: %s", id.to_string()
            );
        }

        Geary.Email? email = this.email_by_id.get(graph.graph_id);
        if (email == null) {
            throw new Geary.EngineError.NOT_FOUND(
                "Unknown Graph email identifier: %s", graph.graph_id
            );
        }

        if (!email.fields.fulfills(required_fields) &&
            required_fields.requires_any(Geary.Email.Field.BODY | Geary.Email.Field.HEADER) &&
            is_open_now) {
            Geary.Graph.Client.Message full = yield this.client.fetch_message(
                graph.graph_id, cancellable
            );
            this.message_by_id.set(full.id, full);
            build_email(full, email);
            try {
                Geary.Memory.Buffer full_rfc822 =
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
        }

        if (!email.fields.fulfills(required_fields)) {
            throw new Geary.EngineError.INCOMPLETE_MESSAGE(
                "Required fields not available for Graph message %s", graph.graph_id
            );
        }
        return email;
    }

    public override void set_used_as_custom(bool enabled) {
        Geary.Folder.SpecialUse old_use = this._used_as;
        this._used_as = enabled ? Geary.Folder.SpecialUse.CUSTOM : Geary.Folder.SpecialUse.NONE;
        notify_use_changed(old_use, this._used_as);
    }

    public async void mark_email_async(Gee.Collection<Geary.EmailIdentifier> to_mark,
                                       Geary.EmailFlags? flags_to_add,
                                       Geary.EmailFlags? flags_to_remove,
                                       GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        check_open();
        yield ensure_loaded(cancellable);
        if (flags_to_add == null && flags_to_remove == null) {
            return;
        }
        Gee.HashMap<Geary.EmailIdentifier,Geary.EmailFlags> changed =
            new Gee.HashMap<Geary.EmailIdentifier,Geary.EmailFlags>();
        foreach (Geary.EmailIdentifier id in to_mark) {
            Geary.Graph.EmailIdentifier? graph = id as Geary.Graph.EmailIdentifier;
            if (graph == null) {
                continue;
            }
            Geary.Email? email = this.email_by_id.get(graph.graph_id);
            if (email == null) {
                continue;
            }

            bool? is_read = null;
            bool? is_flagged = null;
            if (flags_to_add != null) {
                if (flags_to_add.contains(Geary.EmailFlags.UNREAD)) {
                    is_read = false;
                }
                if (flags_to_add.contains(Geary.EmailFlags.FLAGGED)) {
                    is_flagged = true;
                }
            }
            if (flags_to_remove != null) {
                if (flags_to_remove.contains(Geary.EmailFlags.UNREAD)) {
                    is_read = true;
                }
                if (flags_to_remove.contains(Geary.EmailFlags.FLAGGED)) {
                    is_flagged = false;
                }
            }
            if (is_read == null && is_flagged == null) {
                continue;
            }

            Geary.EmailFlags updated = email.email_flags ?? new Geary.EmailFlags();
            if (is_read != null) {
                if (is_read == true) {
                    updated.remove(Geary.EmailFlags.UNREAD);
                } else {
                    updated.add(Geary.EmailFlags.UNREAD);
                }
            }
            if (is_flagged != null) {
                if (is_flagged == true) {
                    updated.add(Geary.EmailFlags.FLAGGED);
                } else {
                    updated.remove(Geary.EmailFlags.FLAGGED);
                }
            }
            email.set_flags(updated);
            changed.set(email.id, updated);

            Geary.Graph.Client.Message? message = this.message_by_id.get(graph.graph_id);
            if (message != null) {
                if (is_read != null) {
                    message.is_read = (is_read == true);
                }
                if (is_flagged != null) {
                    message.is_flagged = (is_flagged == true);
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

    public async Geary.Revokable?
        move_email_async(Gee.Collection<Geary.EmailIdentifier> to_move,
                         Geary.FolderPath destination,
                         GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        check_open();
        yield ensure_loaded(cancellable);

        Geary.Graph.Folder destination_folder = get_destination_folder(destination);
        if (destination_folder.path.compare_to(this.path) == 0) {
            return new Geary.Graph.NoopRevokable();
        }

        Gee.ArrayList<Geary.EmailIdentifier> moved = new Gee.ArrayList<Geary.EmailIdentifier>();
        Gee.ArrayList<string> moved_ids = new Gee.ArrayList<string>();
        foreach (Geary.EmailIdentifier id in to_move) {
            Geary.Graph.EmailIdentifier? graph = id as Geary.Graph.EmailIdentifier;
            if (graph == null || !this.email_by_id.has_key(graph.graph_id)) {
                continue;
            }
            moved.add(id);
            moved_ids.add(graph.graph_id);
        }

        Gee.ArrayList<Geary.EmailIdentifier> removed = remove_cached_emails(moved);
        if (!removed.is_empty) {
            notify_email_removed(removed);
        }
        if (!moved_ids.is_empty) {
            bool refresh_destination = destination_folder.is_cache_loaded;
            int pending = moved_ids.size;
            foreach (string graph_id in moved_ids) {
                this.client.move_message.begin(
                    graph_id,
                    destination_folder.graph_folder_id,
                    cancellable,
                    (obj, res) => {
                        try {
                            this.client.move_message.end(res);
                        } catch (GLib.Error err) {
                            warning(
                                "Graph move failed for %s: %s",
                                graph_id,
                                err.message
                            );
                        }
                        pending--;
                        if (pending == 0 && refresh_destination) {
                            destination_folder.refresh_async.begin(
                                true,
                                cancellable,
                                (refresh_obj, refresh_res) => {
                                    try {
                                        destination_folder.refresh_async.end(refresh_res);
                                    } catch (GLib.Error err) {
                                        warning(
                                            "Graph refresh failed for %s: %s",
                                            destination_folder.path.to_string(),
                                            err.message
                                        );
                                    }
                                }
                            );
                        }
                    }
                );
            }
        }

        return new Geary.Graph.NoopRevokable();
    }

    public async Geary.Revokable?
        archive_email_async(Gee.Collection<Geary.EmailIdentifier> email_ids,
                            GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        Geary.Graph.Folder? archive =
            this.owner.get_graph_special_folder(Geary.Folder.SpecialUse.ARCHIVE);
        if (archive == null) {
            throw new Geary.EngineError.NOT_FOUND(
                "No archive folder available for Graph account"
            );
        }
        return yield move_email_async(email_ids, archive.path, cancellable);
    }

    public async void remove_email_async(Gee.Collection<Geary.EmailIdentifier> email_ids,
                                         GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        check_open();
        yield ensure_loaded(cancellable);
        Gee.ArrayList<Geary.EmailIdentifier> removed = new Gee.ArrayList<Geary.EmailIdentifier>();
        foreach (Geary.EmailIdentifier id in email_ids) {
            Geary.Graph.EmailIdentifier? graph = id as Geary.Graph.EmailIdentifier;
            if (graph == null || !this.email_by_id.has_key(graph.graph_id)) {
                continue;
            }
            yield this.client.delete_message(graph.graph_id, cancellable);
            removed.add(id);
        }
        removed = remove_cached_emails(removed);
        if (!removed.is_empty) {
            notify_email_removed(removed);
        }
    }

    public async void copy_email_async(Gee.Collection<Geary.EmailIdentifier> to_copy,
                                       Geary.FolderPath destination,
                                       GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        check_open();
        yield ensure_loaded(cancellable);
        Geary.Graph.Folder destination_folder = get_destination_folder(destination);
        if (destination_folder.path.compare_to(this.path) == 0) {
            return;
        }
        foreach (Geary.EmailIdentifier id in to_copy) {
            Geary.Graph.EmailIdentifier? graph = id as Geary.Graph.EmailIdentifier;
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

        Gee.List<Geary.Graph.Client.Message> messages = yield this.client.list_messages(
            this.folder_id,
            get_refresh_limit(),
            this.owner.information.prefetch_period_days,
            cancellable
        );

        bool had_loaded = this.is_loaded;
        int previous_total = this._properties.email_total;
        Gee.Set<string> refreshed_ids = new Gee.HashSet<string>();
        Gee.ArrayList<Geary.EmailIdentifier> appended = new Gee.ArrayList<Geary.EmailIdentifier>();
        Gee.ArrayList<Geary.EmailIdentifier> inserted = new Gee.ArrayList<Geary.EmailIdentifier>();
        Gee.ArrayList<Geary.EmailIdentifier> removed = new Gee.ArrayList<Geary.EmailIdentifier>();
        Gee.HashMap<Geary.EmailIdentifier, Geary.EmailFlags> flags_changed =
            new Gee.HashMap<Geary.EmailIdentifier, Geary.EmailFlags>();

        // Find the newest email timestamp in the existing cache
        int64 newest_cached_timestamp = 0;
        if (had_loaded && this.email_cache.size > 0) {
            foreach (Geary.Email cached_email in this.email_cache) {
                Geary.Graph.EmailIdentifier? graph_id = cached_email.id as Geary.Graph.EmailIdentifier;
                if (graph_id != null && graph_id.sort_order > newest_cached_timestamp) {
                    newest_cached_timestamp = graph_id.sort_order;
                }
            }
        }

        foreach (Geary.Graph.Client.Message message in messages) {
            if (String.is_empty(message.id)) {
                continue;
            }
            refreshed_ids.add(message.id);
            Geary.Email? existing = this.email_by_id.get(message.id);
            Geary.EmailFlags? old_flags = null;
            if (existing != null && existing.email_flags != null) {
                old_flags = new Geary.EmailFlags();
                old_flags.add_all(existing.email_flags);
            }

            Geary.Email email = build_email(message, existing);
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
        if (had_loaded) {
            Gee.ArrayList<string> stale_ids = new Gee.ArrayList<string>();
            foreach (string cached_id in this.email_by_id.keys) {
                if (refreshed_ids.contains(cached_id)) {
                    continue;
                }
                stale_ids.add(cached_id);
            }
            foreach (string cached_id in stale_ids) {
                Geary.Email? cached = this.email_by_id.get(cached_id);
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
            Geary.Folder.CountChangeReason reason =
                this._properties.email_total > previous_total
                ? Geary.Folder.CountChangeReason.INSERTED
                : Geary.Folder.CountChangeReason.REMOVED;
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

        if (!flags_changed.is_empty) {
            notify_email_flags_changed(flags_changed);
        }

        if (!removed.is_empty) {
            notify_email_removed(removed);
        }
        persist_cached_messages();
        this.is_loaded = true;
    }

    internal async bool has_identifier_async(Geary.EmailIdentifier id,
                                             GLib.Cancellable? cancellable)
        throws GLib.Error {
        yield ensure_loaded(cancellable);
        return has_cached_identifier(id);
    }

    internal bool has_cached_identifier(Geary.EmailIdentifier id) {
        Geary.Graph.EmailIdentifier? graph = id as Geary.Graph.EmailIdentifier;
        return graph != null && this.email_by_id.has_key(graph.graph_id);
    }

    internal Gee.Collection<Geary.Email> list_cached_emails() {
        return this.email_cache.read_only_view;
    }

    private Geary.Graph.Folder get_destination_folder(Geary.FolderPath destination)
        throws GLib.Error {
        Geary.Graph.Folder? folder = this.owner.get_graph_folder(destination);
        if (folder == null) {
            throw new Geary.EngineError.NOT_FOUND(
                "Unknown Graph folder: %s",
                destination.to_string()
            );
        }
        return folder;
    }

    private Gee.ArrayList<Geary.EmailIdentifier>
        remove_cached_emails(Gee.Collection<Geary.EmailIdentifier> ids) {
        int previous_total = this._properties.email_total;
        Gee.ArrayList<Geary.EmailIdentifier> removed = new Gee.ArrayList<Geary.EmailIdentifier>();
        foreach (Geary.EmailIdentifier id in ids) {
            Geary.Graph.EmailIdentifier? graph = id as Geary.Graph.EmailIdentifier;
            if (graph == null) {
                continue;
            }
            Geary.Email? email = this.email_by_id.get(graph.graph_id);
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
                    Geary.Folder.CountChangeReason.REMOVED
                );
            }
            persist_cached_messages();
        }
        return removed;
    }

    private int count_unread() {
        int unread = 0;
        foreach (Geary.Email email in this.email_cache) {
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

    private Geary.Email build_email(Geary.Graph.Client.Message message,
                                    Geary.Email? existing = null) {
        Geary.Email email = existing ?? new Geary.Email(
            new Geary.Graph.EmailIdentifier(
                message.id,
                message.received_at != null ? message.received_at.to_unix() : 0
            )
        );

        if (message.received_at != null) {
            email.set_send_date(new Geary.RFC822.Date(message.received_at));
        }
        Geary.RFC822.MailboxAddresses? from = message.from;
        if (from == null || from.is_empty) {
            from = new Geary.RFC822.MailboxAddresses.single(
                this.owner.information.primary_mailbox
            );
        }
        Geary.RFC822.MailboxAddresses to =
            message.to ?? new Geary.RFC822.MailboxAddresses();
        Geary.RFC822.MailboxAddresses cc =
            message.cc ?? new Geary.RFC822.MailboxAddresses();
        Geary.RFC822.MailboxAddresses bcc =
            message.bcc ?? new Geary.RFC822.MailboxAddresses();
        try {
            email.set_originators(from, null, null);
        } catch (GLib.Error err) {
            debug("Error setting Graph originators: %s", err.message);
        }
        email.set_receivers(to, cc, bcc);

        Geary.RFC822.MessageID? message_id = build_message_id(message);
        Geary.RFC822.MessageIDList? references = build_conversation_references(message);
        if (message_id != null || references != null) {
            email.set_full_references(message_id, null, references);
        }

        email.set_message_subject(new Geary.RFC822.Subject(message.subject));
        email.set_message_preview(
            new Geary.RFC822.PreviewText.from_string(message.body_preview)
        );

        var flags = new Geary.EmailFlags();
        if (!message.is_read) {
            flags.add(Geary.EmailFlags.UNREAD);
        }
        if (message.is_flagged) {
            flags.add(Geary.EmailFlags.FLAGGED);
        }
        email.set_flags(flags);

        GLib.DateTime received = message.received_at ?? new GLib.DateTime.now_local();
        email.set_email_properties(new Geary.Graph.EmailProperties(received, message.size));

        if (message.body != null) {
            string body = message.body;
            email.set_message_body(new Geary.RFC822.Text(new Geary.Memory.StringBuffer(body)));
            Geary.RFC822.Header? header = build_header(message);
            if (header != null) {
                email.set_message_header(header);
            }
        }

        return email;
    }

    private Geary.RFC822.Header? build_header(Geary.Graph.Client.Message message) {
        Geary.RFC822.Date sent = new Geary.RFC822.Date(
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
            header += "Subject: %s\r\n".printf(new Geary.RFC822.Subject(message.subject).to_rfc822_string());
        }
        Geary.RFC822.MessageID? message_id = build_message_id(message);
        if (message_id != null) {
            header += "Message-Id: %s\r\n".printf(message_id.to_rfc822_string());
        }
        Geary.RFC822.MessageIDList? references = build_conversation_references(message);
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
            return new Geary.RFC822.Header(new Geary.Memory.StringBuffer(header));
        } catch (Geary.RFC822.Error err) {
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

    private void populate_full_message(Geary.Email email,
                                       Geary.Memory.Buffer full_rfc822,
                                       string graph_message_id) {
        Geary.RFC822.Message parsed;
        try {
            parsed = new Geary.RFC822.Message.from_buffer(full_rfc822);
        } catch (Geary.RFC822.Error err) {
            debug("Error parsing Graph RFC822 payload: %s", err.message);
            return;
        }

        email.set_message_header(parsed.get_header());
        email.set_message_body(parsed.get_body());
        string preview = parsed.get_preview();
        if (!String.is_empty(preview)) {
            email.set_message_preview(
                new Geary.RFC822.PreviewText.from_string(preview)
            );
        }

        if (email.attachments.is_empty) {
            populate_attachments(email, parsed, graph_message_id);
        }
    }

    private void populate_attachments(Geary.Email email,
                                      Geary.RFC822.Message parsed,
                                      string graph_message_id) {
        Gee.List<Geary.RFC822.Part> parts;
        try {
            parts = parsed.get_attachments();
        } catch (Geary.RFC822.Error err) {
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
        foreach (Geary.RFC822.Part part in parts) {
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
                Geary.Memory.Buffer content = part.write_to_buffer(
                    Geary.RFC822.Part.EncodingConversion.NONE
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
                    new Geary.Graph.Attachment.from_part(
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

    private Geary.RFC822.MessageIDList? build_conversation_references(
        Geary.Graph.Client.Message message
    ) {
        if (String.is_empty(message.conversation_id)) {
            return null;
        }
        string conversation_hash = GLib.Checksum.compute_for_string(
            GLib.ChecksumType.SHA1,
            message.conversation_id
        );
        Geary.RFC822.MessageID conversation_id = new Geary.RFC822.MessageID(
            "graph-conversation-%s@geary.local".printf(conversation_hash)
        );
        return new Geary.RFC822.MessageIDList.single(conversation_id);
    }

    private Geary.RFC822.MessageID? build_message_id(Geary.Graph.Client.Message message) {
        if (!String.is_empty(message.internet_message_id)) {
            try {
                return new Geary.RFC822.MessageID.from_rfc822_string(
                    message.internet_message_id
                );
            } catch (Geary.RFC822.Error err) {
                debug("Error parsing Graph message-id: %s", err.message);
            }
        }
        if (String.is_empty(message.id)) {
            return null;
        }
        return new Geary.RFC822.MessageID("graph-%s@geary.local".printf(message.id));
    }

    private string? compute_cache_path() {
        GLib.File? data_dir = this.owner.information.data_dir;
        if (data_dir == null) {
            return null;
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
            for (uint i = 0; i < messages.get_length(); i++) {
                Json.Node item = messages.get_element(i);
                if (item.get_node_type() != Json.NodeType.OBJECT) {
                    continue;
                }
                Geary.Graph.Client.Message parsed = parse_cached_message(
                    messages.get_object_element(i)
                );
                if (String.is_empty(parsed.id)) {
                    continue;
                }
                Geary.Email email = build_email(parsed);
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
            builder.set_member_name("messages");
            builder.begin_array();
            foreach (Geary.Email email in this.email_cache) {
                Geary.Graph.EmailIdentifier? graph_id = email.id as Geary.Graph.EmailIdentifier;
                if (graph_id == null) {
                    continue;
                }
                Geary.Graph.Client.Message? message = this.message_by_id.get(graph_id.graph_id);
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

    private static Geary.Graph.Client.Message parse_cached_message(Json.Object object) {
        Geary.Graph.Client.Message parsed = new Geary.Graph.Client.Message();
        parsed.id = get_string_member(object, "id") ?? "";
        parsed.conversation_id = get_string_member(object, "conversationId") ?? "";
        parsed.subject = get_string_member(object, "subject") ?? "";
        parsed.internet_message_id = get_string_member(object, "internetMessageId") ?? "";
        parsed.body_preview = get_string_member(object, "bodyPreview") ?? "";
        parsed.body = get_string_member(object, "body");
        parsed.body_content_type = get_string_member(object, "bodyContentType") ?? "text";
        parsed.is_read = get_bool_member(object, "isRead", true);
        parsed.is_flagged = get_bool_member(object, "isFlagged", false);
        parsed.received_at = parse_datetime(get_string_member(object, "receivedDateTime"));
        parsed.size = get_int_member(object, "size", 0);
        parsed.from = parse_addresses_member(object, "from");
        parsed.to = parse_addresses_member(object, "to");
        parsed.cc = parse_addresses_member(object, "cc");
        parsed.bcc = parse_addresses_member(object, "bcc");
        return parsed;
    }

    private static void append_cached_message(Json.Builder builder,
                                              Geary.Graph.Client.Message message) {
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

    private static string? to_rfc822_string(Geary.RFC822.MailboxAddresses? addresses) {
        return (addresses == null || addresses.is_empty)
            ? null
            : addresses.to_rfc822_string();
    }

    private static Geary.RFC822.MailboxAddresses? parse_addresses_member(Json.Object object,
                                                                          string key) {
        string? value = get_string_member(object, key);
        if (String.is_empty(value)) {
            return null;
        }
        try {
            return new Geary.RFC822.MailboxAddresses.from_rfc822_string(value);
        } catch (Geary.RFC822.Error err) {
        }
        return null;
    }

    private static string? get_string_member(Json.Object object, string key) {
        if (!object.has_member(key)) {
            return null;
        }
        Json.Node member = object.get_member(key);
        if (member == null ||
            member.get_node_type() != Json.NodeType.VALUE ||
            member.get_value_type() != typeof(string)) {
            return null;
        }
        return member.get_string();
    }

    private static void set_string_member(Json.Builder builder, string key, string? value) {
        if (String.is_empty(value)) {
            return;
        }
        builder.set_member_name(key);
        builder.add_string_value(value);
    }

    private static bool get_bool_member(Json.Object object,
                                        string key,
                                        bool default_value) {
        if (!object.has_member(key)) {
            return default_value;
        }
        Json.Node member = object.get_member(key);
        if (member != null &&
            member.get_node_type() == Json.NodeType.VALUE &&
            member.get_value_type() == typeof(bool)) {
            return member.get_boolean();
        }
        return default_value;
    }

    private static int64 get_int_member(Json.Object object,
                                        string key,
                                        int64 default_value) {
        if (!object.has_member(key)) {
            return default_value;
        }
        Json.Node member = object.get_member(key);
        if (member != null &&
            member.get_node_type() == Json.NodeType.VALUE &&
            (member.get_value_type() == typeof(int64) ||
             member.get_value_type() == typeof(int))) {
            return member.get_int();
        }
        return default_value;
    }

    private static GLib.DateTime? parse_datetime(string? value) {
        if (String.is_empty(value)) {
            return null;
        }
        return new GLib.DateTime.from_iso8601(value, null);
    }

    private static int find_index(Gee.List<Geary.Email> emails, Geary.EmailIdentifier id) {
        for (int i = 0; i < emails.size; i++) {
            if (emails[i].id.equal_to(id)) {
                return i;
            }
        }
        return -1;
    }

}

internal class Geary.Graph.NoopRevokable : Geary.Revokable {

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
