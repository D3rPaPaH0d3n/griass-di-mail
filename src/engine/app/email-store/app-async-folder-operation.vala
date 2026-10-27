/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

private abstract class GriabuntuMail.App.AsyncFolderOperation : BaseObject {
    public abstract Type folder_type { get; }

    public abstract async Gee.Collection<GriabuntuMail.EmailIdentifier> execute_async(
        GriabuntuMail.Folder folder, Gee.Collection<GriabuntuMail.EmailIdentifier> ids,
        Cancellable? cancellable) throws Error;
}
