/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

private class GriabuntuMail.App.LocalSearchOperation : GriabuntuMail.Nonblocking.BatchOperation {
    // IN
    public GriabuntuMail.Account account;
    public RFC822.MessageID message_id;
    public GriabuntuMail.Email.Field required_fields;
    public Gee.Collection<GriabuntuMail.FolderPath>? blacklist;
    public GriabuntuMail.EmailFlags? flag_blacklist;

    // OUT
    public Gee.MultiMap<GriabuntuMail.Email, GriabuntuMail.FolderPath?>? emails = null;

    public LocalSearchOperation(GriabuntuMail.Account account, RFC822.MessageID message_id,
        GriabuntuMail.Email.Field required_fields, Gee.Collection<GriabuntuMail.FolderPath?> blacklist,
        GriabuntuMail.EmailFlags? flag_blacklist) {
        this.account = account;
        this.message_id = message_id;
        this.required_fields = required_fields;
        this.blacklist = blacklist;
        this.flag_blacklist = flag_blacklist;
    }

    public override async Object? execute_async(Cancellable? cancellable) throws Error {
        emails = yield account.local_search_message_id_async(message_id, required_fields,
            false, blacklist, flag_blacklist);

        return null;
    }
}
