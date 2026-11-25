/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

private class GriabuntuMail.App.CopyOperation : GriabuntuMail.App.AsyncFolderOperation {
    public override Type folder_type { get { return typeof(GriabuntuMail.FolderSupport.Copy); } }

    public GriabuntuMail.FolderPath destination;

    public CopyOperation(GriabuntuMail.FolderPath destination) {
        this.destination = destination;
    }

    public override async Gee.Collection<GriabuntuMail.EmailIdentifier> execute_async(
        GriabuntuMail.Folder folder, Gee.Collection<GriabuntuMail.EmailIdentifier> ids,
        Cancellable? cancellable) throws Error {
        GriabuntuMail.FolderSupport.Copy? copy = folder as GriabuntuMail.FolderSupport.Copy;
        assert(copy != null);

        yield copy.copy_email_async(
            Collection.copy(ids), destination, cancellable
        );
        return ids;
    }
}
