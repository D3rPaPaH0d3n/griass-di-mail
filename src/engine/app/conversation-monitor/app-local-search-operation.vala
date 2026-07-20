/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

private class Convey.App.LocalSearchOperation : Convey.Nonblocking.BatchOperation {
    // IN
    public Convey.Account account;
    public RFC822.MessageID message_id;
    public Convey.Email.Field required_fields;
    public Gee.Collection<Convey.FolderPath>? blacklist;
    public Convey.EmailFlags? flag_blacklist;

    // OUT
    public Gee.MultiMap<Convey.Email, Convey.FolderPath?>? emails = null;

    public LocalSearchOperation(Convey.Account account, RFC822.MessageID message_id,
        Convey.Email.Field required_fields, Gee.Collection<Convey.FolderPath?> blacklist,
        Convey.EmailFlags? flag_blacklist) {
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
