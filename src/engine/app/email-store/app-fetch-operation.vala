/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

private class Convey.App.FetchOperation : Convey.App.AsyncFolderOperation {
    public override Type folder_type { get { return typeof(Convey.Folder); } }

    public Convey.Email? result = null;
    public Convey.Email.Field required_fields;
    public Convey.Folder.ListFlags flags;

    public FetchOperation(Convey.Email.Field required_fields, Convey.Folder.ListFlags flags) {
        this.required_fields = required_fields;
        this.flags = flags;
    }

    public override async Gee.Collection<Convey.EmailIdentifier> execute_async(
        Convey.Folder folder, Gee.Collection<Convey.EmailIdentifier> ids,
        Cancellable? cancellable) throws Error {
        assert(result == null);
        Convey.EmailIdentifier? id = Collection.first(ids);
        assert(id != null);

        result = yield folder.fetch_email_async(
            id, required_fields, flags, cancellable);
        return Convey.iterate<Convey.EmailIdentifier>(id).to_array_list();
    }
}
