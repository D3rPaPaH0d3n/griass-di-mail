/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

public class GriabuntuMail.App.EmailStore : BaseObject {
    public weak GriabuntuMail.Account account { get; private set; }

    public EmailStore(GriabuntuMail.Account account) {
        this.account = account;
    }

    /**
     * Return a map of EmailIdentifiers to the special GriabuntuMail.FolderSupport
     * interfaces each one supports.  For example, if an EmailIdentifier comes
     * back mapped to typeof(GriabuntuMail.FolderSupport.Mark), it can be marked via
     * mark_email_async().  If an EmailIdentifier doesn't appear in the
     * returned map, no operations are supported on it.
     */
    public async Gee.MultiMap<GriabuntuMail.EmailIdentifier, Type>? get_supported_operations_async(
        Gee.Collection<GriabuntuMail.EmailIdentifier> emails, Cancellable? cancellable = null) throws Error {
        Gee.MultiMap<GriabuntuMail.EmailIdentifier, GriabuntuMail.FolderPath>? folders
            = yield account.get_containing_folders_async(emails, cancellable);
        if (folders == null)
            return null;

        Gee.HashSet<Type> all_support = new Gee.HashSet<Type>();
        all_support.add(typeof(GriabuntuMail.FolderSupport.Archive));
        all_support.add(typeof(GriabuntuMail.FolderSupport.Copy));
        all_support.add(typeof(GriabuntuMail.FolderSupport.Create));
        all_support.add(typeof(GriabuntuMail.FolderSupport.Mark));
        all_support.add(typeof(GriabuntuMail.FolderSupport.Move));
        all_support.add(typeof(GriabuntuMail.FolderSupport.Remove));

        Gee.HashMultiMap<GriabuntuMail.EmailIdentifier, Type> map
            = new Gee.HashMultiMap<GriabuntuMail.EmailIdentifier, Type>();
        foreach (GriabuntuMail.EmailIdentifier email in folders.get_keys()) {
            Gee.HashSet<Type> support = new Gee.HashSet<Type>();

            foreach (GriabuntuMail.FolderPath path in folders.get(email)) {
                GriabuntuMail.Folder folder;
                try {
                    folder = account.get_folder(path);
                } catch (Error e) {
                    debug("Error getting a folder from path %s: %s", path.to_string(), e.message);
                    continue;
                }

                foreach (Type type in all_support) {
                    if (folder.get_type().is_a(type))
                        support.add(type);
                }
                if (support.contains_all(all_support))
                    break;
            }

            GriabuntuMail.Collection.multi_map_set_all<GriabuntuMail.EmailIdentifier, Type>(map, email, support);
        }

        return (map.size > 0 ? map : null);
    }

    /**
     * Lists any set of EmailIdentifiers as if they were all in one folder.
     */
    public async Gee.Collection<GriabuntuMail.Email>? list_email_by_sparse_id_async(
        Gee.Collection<GriabuntuMail.EmailIdentifier> emails, GriabuntuMail.Email.Field required_fields,
        GriabuntuMail.Folder.ListFlags flags, Cancellable? cancellable = null) throws Error {
        ListOperation op = new GriabuntuMail.App.ListOperation(required_fields, flags);
        yield do_folder_operation_async(op, emails, cancellable);
        return (op.results.size > 0 ? op.results : null);
    }

    /**
     * Fetches any EmailIdentifier regardless of what folder it's in.
     */
    public async GriabuntuMail.Email fetch_email_async(GriabuntuMail.EmailIdentifier email_id,
        GriabuntuMail.Email.Field required_fields, GriabuntuMail.Folder.ListFlags flags,
        Cancellable? cancellable = null) throws Error {
        FetchOperation op = new GriabuntuMail.App.FetchOperation(required_fields, flags);
        yield do_folder_operation_async(op,
            GriabuntuMail.iterate<GriabuntuMail.EmailIdentifier>(email_id).to_array_list(), cancellable);

        if (op.result == null)
            throw new EngineError.NOT_FOUND("Couldn't fetch email ID %s", email_id.to_string());
        return op.result;
    }

    /**
     * Marks any set of EmailIdentifiers as if they were all in one
     * GriabuntuMail.FolderSupport.Mark folder.
     */
    public async void mark_email_async(Gee.Collection<GriabuntuMail.EmailIdentifier> emails,
        GriabuntuMail.EmailFlags? flags_to_add, GriabuntuMail.EmailFlags? flags_to_remove,
        Cancellable? cancellable = null) throws Error {
        yield do_folder_operation_async(new GriabuntuMail.App.MarkOperation(flags_to_add, flags_to_remove),
            emails, cancellable);
    }

    /**
     * Copies any set of EmailIdentifiers as if they were all in one
     * GriabuntuMail.FolderSupport.Copy folder.
     */
    public async void copy_email_async(Gee.Collection<GriabuntuMail.EmailIdentifier> emails,
        GriabuntuMail.FolderPath destination, Cancellable? cancellable = null) throws Error {
        yield do_folder_operation_async(new GriabuntuMail.App.CopyOperation(destination),
            emails, cancellable);
    }

    private FolderPath?
        next_folder_for_operation(AsyncFolderOperation operation,
                                  Gee.MultiMap<FolderPath,EmailIdentifier> folders_to_ids)
        throws GLib.Error {
        bool best_is_open = false;
        int best_count = 0;
        GriabuntuMail.FolderPath? best = null;
        foreach (GriabuntuMail.FolderPath path in folders_to_ids.get_keys()) {
            Folder folder = this.account.get_folder(path);
            if (!folder.get_type().is_a(operation.folder_type))
                continue;

            int count = folders_to_ids.get(path).size;
            if (count == 0)
                continue;

            if (folder.get_open_state() == GriabuntuMail.Folder.OpenState.REMOTE) {
                if (!best_is_open) {
                    best_is_open = true;
                    best_count = 0;
                }
            } else if (best_is_open) {
                continue;
            }

            if (count > best_count) {
                best_count = count;
                best = path;
            }
        }

        return best;
    }

    private async void do_folder_operation_async(AsyncFolderOperation operation,
        Gee.Collection<GriabuntuMail.EmailIdentifier> emails, Cancellable? cancellable) throws Error {
        if (emails.size == 0)
            return;

        debug("EmailStore %s running %s on %d emails", account.to_string(),
            operation.get_type().name(), emails.size);

        Gee.MultiMap<GriabuntuMail.EmailIdentifier, GriabuntuMail.FolderPath>? ids_to_folders
            = yield account.get_containing_folders_async(emails, cancellable);
        if (ids_to_folders == null)
            return;

        Gee.MultiMap<GriabuntuMail.FolderPath, GriabuntuMail.EmailIdentifier> folders_to_ids
            = GriabuntuMail.Collection.reverse_multi_map<GriabuntuMail.EmailIdentifier, GriabuntuMail.FolderPath>(ids_to_folders);
        GriabuntuMail.FolderPath? path;
        while ((path = next_folder_for_operation(operation, folders_to_ids)) != null) {
            GriabuntuMail.Folder folder = this.account.get_folder(path);
            Gee.Collection<GriabuntuMail.EmailIdentifier> ids = folders_to_ids.get(path);
            assert(ids.size > 0);

            bool open = false;
            Gee.Collection<GriabuntuMail.EmailIdentifier>? used_ids = null;
            GLib.Error? op_error = null;
            try {
                yield folder.open_async(Folder.OpenFlags.NONE, cancellable);
                open = true;
                used_ids = yield operation.execute_async(folder, ids, cancellable);
            } catch (GLib.Error err) {
                op_error = err;
            }

            if (open) {
                try {
                    // Don't use the cancellable here, if it's been opened
                    // we need to try to close it.
                    yield folder.close_async(null);
                } catch (Error e) {
                    warning("Error closing folder %s: %s",
                            folder.to_string(), e.message);
                }
            }

            if (op_error != null) {
                throw op_error;
            }

            // We don't want to operate on any mails twice.
            if (used_ids != null) {
                foreach (GriabuntuMail.EmailIdentifier id in used_ids.to_array()) {
                    foreach (GriabuntuMail.FolderPath p in ids_to_folders.get(id))
                        folders_to_ids.remove(p, id);
                }
            }
            // And we don't want to operate on the same folder twice.
            folders_to_ids.remove_all(path);
        }

        if (folders_to_ids.size > 0) {
            debug("Couldn't perform %s on some messages in %s", operation.get_type().name(),
                account.to_string());
        }
    }
}
