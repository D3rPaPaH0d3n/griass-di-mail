/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */


/**
 * A replay operation for a user-initiated operation.
 */
private abstract class Convey.ImapEngine.SendReplayOperation : Convey.ImapEngine.ReplayOperation {
    protected SendReplayOperation(string name, ReplayOperation.OnError on_remote_error = OnError.THROW) {
        base (name, ReplayOperation.Scope.LOCAL_AND_REMOTE, on_remote_error);
    }

    protected SendReplayOperation.only_local(string name, ReplayOperation.OnError on_remote_error = OnError.THROW) {
        base (name, ReplayOperation.Scope.LOCAL_ONLY, on_remote_error);
    }

    protected SendReplayOperation.only_remote(string name, ReplayOperation.OnError on_remote_error = OnError.THROW) {
        base (name, ReplayOperation.Scope.REMOTE_ONLY, on_remote_error);
    }

    public override void notify_remote_removed_position(Imap.SequenceNumber removed) {
        // we've worked very hard to keep positional addressing out of the SendReplayOperations
    }

}
