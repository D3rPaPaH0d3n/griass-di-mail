/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

private class Convey.App.MarkOperation : Convey.App.AsyncFolderOperation {
    public override Type folder_type { get { return typeof(Convey.FolderSupport.Mark); } }

    public Convey.EmailFlags? flags_to_add;
    public Convey.EmailFlags? flags_to_remove;

    public MarkOperation(Convey.EmailFlags? flags_to_add, Convey.EmailFlags? flags_to_remove) {
        this.flags_to_add = flags_to_add;
        this.flags_to_remove = flags_to_remove;
    }

    public override async Gee.Collection<Convey.EmailIdentifier> execute_async(
        Convey.Folder folder, Gee.Collection<Convey.EmailIdentifier> ids,
        Cancellable? cancellable) throws Error {
        Convey.FolderSupport.Mark? mark = folder as Convey.FolderSupport.Mark;
        assert(mark != null);

        yield mark.mark_email_async(
            Collection.copy(ids), flags_to_add, flags_to_remove, cancellable
        );
        return ids;
    }
}
