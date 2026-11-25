/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

private class GriabuntuMail.App.ListOperation : GriabuntuMail.App.AsyncFolderOperation {
    public override Type folder_type { get { return typeof(GriabuntuMail.Folder); } }

    public Gee.HashSet<GriabuntuMail.Email> results;
    public GriabuntuMail.Email.Field required_fields;
    public GriabuntuMail.Folder.ListFlags flags;

    public ListOperation(GriabuntuMail.Email.Field required_fields, GriabuntuMail.Folder.ListFlags flags) {
        results = new Gee.HashSet<GriabuntuMail.Email>();
        this.required_fields = required_fields;
        this.flags = flags;
    }

    public override async Gee.Collection<GriabuntuMail.EmailIdentifier> execute_async(
        GriabuntuMail.Folder folder, Gee.Collection<GriabuntuMail.EmailIdentifier> ids,
        Cancellable? cancellable) throws Error {
        Gee.List<GriabuntuMail.Email>? list = yield folder.list_email_by_sparse_id_async(
            ids, required_fields, flags, cancellable);
        if (list != null)
            results.add_all(list);
        return ids;
    }
}
