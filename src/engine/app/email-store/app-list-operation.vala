/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

private class Convey.App.ListOperation : Convey.App.AsyncFolderOperation {
    public override Type folder_type { get { return typeof(Convey.Folder); } }

    public Gee.HashSet<Convey.Email> results;
    public Convey.Email.Field required_fields;
    public Convey.Folder.ListFlags flags;

    public ListOperation(Convey.Email.Field required_fields, Convey.Folder.ListFlags flags) {
        results = new Gee.HashSet<Convey.Email>();
        this.required_fields = required_fields;
        this.flags = flags;
    }

    public override async Gee.Collection<Convey.EmailIdentifier> execute_async(
        Convey.Folder folder, Gee.Collection<Convey.EmailIdentifier> ids,
        Cancellable? cancellable) throws Error {
        Gee.List<Convey.Email>? list = yield folder.list_email_by_sparse_id_async(
            ids, required_fields, flags, cancellable);
        if (list != null)
            results.add_all(list);
        return ids;
    }
}
