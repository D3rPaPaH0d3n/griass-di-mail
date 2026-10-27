/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

private class GriabuntuMail.ImapEngine.ListEmailBySparseID : GriabuntuMail.ImapEngine.AbstractListEmail {
    private Gee.HashSet<ImapDB.EmailIdentifier> ids = new Gee.HashSet<ImapDB.EmailIdentifier>();

    public ListEmailBySparseID(MinimalFolder owner, Gee.Collection<ImapDB.EmailIdentifier> ids,
        GriabuntuMail.Email.Field required_fields, Folder.ListFlags flags, Cancellable? cancellable) {
        base ("ListEmailBySparseID", owner, required_fields, flags, cancellable);

        this.ids.add_all(ids);
    }

    public override void notify_remote_removed_ids(Gee.Collection<ImapDB.EmailIdentifier> removed_ids) {
        ids.remove_all(removed_ids);

        base.notify_remote_removed_ids(removed_ids);
    }

    public override async ReplayOperation.Status replay_local_async() throws Error {
        if (flags.is_force_update()) {
            Gee.Set<Imap.UID>? uids = yield owner.local_folder.get_uids_async(ids, ImapDB.Folder.ListFlags.NONE,
                cancellable);
            add_many_unfulfilled_fields(uids, required_fields);

            return ReplayOperation.Status.CONTINUE;
        }

        Gee.List<GriabuntuMail.Email>? local_list = yield owner.local_folder.list_email_by_sparse_id_async(ids,
            required_fields, ImapDB.Folder.ListFlags.PARTIAL_OK, cancellable);

        // Build list of emails fully fetched from local store and table of remaining emails by
        // their lack of completeness
        Gee.List<GriabuntuMail.Email> fulfilled = new Gee.ArrayList<GriabuntuMail.Email>();
        if (local_list != null && local_list.size > 0) {
            Gee.Map<GriabuntuMail.EmailIdentifier, GriabuntuMail.Email>? map = Email.emails_to_map(local_list);
            assert(map != null);

            // walk list of *requested* IDs to ensure that unknown are considering unfulfilled
            foreach (ImapDB.EmailIdentifier id in ids) {
                GriabuntuMail.Email? email = map.get(id);

                // if non-null, then the local_folder should've supplied a UID; if null, then
                // it's simply not present in the local folder (since PARTIAL_OK is spec'd), so
                // we have no way of referring to it on the server
                if (email == null)
                    continue;

                // if completely unknown, make sure duplicate detection fields are included; otherwise,
                // if known, then they were pulled down during folder normalization and during
                // vector expansion
                if (!email.fields.fulfills(required_fields)) {
                    add_unfulfilled_fields(((ImapDB.EmailIdentifier) email.id).uid,
                        required_fields.clear(email.fields));
                } else {
                    fulfilled.add(email);
                }
            }
        }

        if (fulfilled.size > 0)
            accumulator.add_all(fulfilled);

        if (flags.is_local_only() || get_unfulfilled_count() == 0)
            return ReplayOperation.Status.COMPLETED;

        return ReplayOperation.Status.CONTINUE;
    }

    public override async void backout_local_async() throws Error {
        // R/O, nothing to backout
    }

    public override string describe_state() {
        return "ids.size=%d required_fields=%Xh flags=%Xh".printf(ids.size, required_fields, flags);
    }
}

