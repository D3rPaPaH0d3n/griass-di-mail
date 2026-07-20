/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

private class Convey.App.CopyOperation : Convey.App.AsyncFolderOperation {
    public override Type folder_type { get { return typeof(Convey.FolderSupport.Copy); } }

    public Convey.FolderPath destination;

    public CopyOperation(Convey.FolderPath destination) {
        this.destination = destination;
    }

    public override async Gee.Collection<Convey.EmailIdentifier> execute_async(
        Convey.Folder folder, Gee.Collection<Convey.EmailIdentifier> ids,
        Cancellable? cancellable) throws Error {
        Convey.FolderSupport.Copy? copy = folder as Convey.FolderSupport.Copy;
        assert(copy != null);

        yield copy.copy_email_async(
            Collection.copy(ids), destination, cancellable
        );
        return ids;
    }
}
