/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * Revoked {@link RevokableMove}: Unmark emails as removed and update counts.
 */

private class Convey.ImapEngine.MoveEmailRevoke : Convey.ImapEngine.SendReplayOperation {
    private MinimalFolder engine;
    private Gee.List<ImapDB.EmailIdentifier> to_revoke = new Gee.ArrayList<ImapDB.EmailIdentifier>();
    private Cancellable? cancellable;

    public MoveEmailRevoke(MinimalFolder engine, Gee.Collection<ImapDB.EmailIdentifier> to_revoke,
        Cancellable? cancellable) {
        base.only_local("MoveEmailRevoke", OnError.RETRY);

        this.engine = engine;

        this.to_revoke.add_all(to_revoke);
        this.cancellable = cancellable;
    }

    public override void notify_remote_removed_ids(Gee.Collection<ImapDB.EmailIdentifier> ids) {
        to_revoke.remove_all(ids);
    }

    public override async ReplayOperation.Status replay_local_async() throws Error {
        if (to_revoke.size == 0)
            return ReplayOperation.Status.COMPLETED;

        Gee.Set<ImapDB.EmailIdentifier>? revoked = yield engine.local_folder.mark_removed_async(
            to_revoke, false, cancellable);
        if (revoked == null || revoked.size == 0)
            return ReplayOperation.Status.COMPLETED;

        int count = this.engine.properties.email_total;
        if (count < 0) {
            count = 0;
        }

        engine.replay_notify_email_inserted(revoked);
        engine.replay_notify_email_count_changed(count + revoked.size,
            Convey.Folder.CountChangeReason.INSERTED);

        return ReplayOperation.Status.COMPLETED;
    }

    public override string describe_state() {
        return "%d email IDs".printf(to_revoke.size);
    }
}
