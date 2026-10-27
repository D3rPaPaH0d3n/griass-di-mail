/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

private class GriabuntuMail.App.MarkOperation : GriabuntuMail.App.AsyncFolderOperation {
    public override Type folder_type { get { return typeof(GriabuntuMail.FolderSupport.Mark); } }

    public GriabuntuMail.EmailFlags? flags_to_add;
    public GriabuntuMail.EmailFlags? flags_to_remove;

    public MarkOperation(GriabuntuMail.EmailFlags? flags_to_add, GriabuntuMail.EmailFlags? flags_to_remove) {
        this.flags_to_add = flags_to_add;
        this.flags_to_remove = flags_to_remove;
    }

    public override async Gee.Collection<GriabuntuMail.EmailIdentifier> execute_async(
        GriabuntuMail.Folder folder, Gee.Collection<GriabuntuMail.EmailIdentifier> ids,
        Cancellable? cancellable) throws Error {
        GriabuntuMail.FolderSupport.Mark? mark = folder as GriabuntuMail.FolderSupport.Mark;
        assert(mark != null);

        yield mark.mark_email_async(
            Collection.copy(ids), flags_to_add, flags_to_remove, cancellable
        );
        return ids;
    }
}
