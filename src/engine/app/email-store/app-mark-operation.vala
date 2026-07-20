/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
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
