/*
 * Copyright 2016 Software Freedom Conservancy Inc.
 * Copyright 2018 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * Operation to close the folder.
 *
 * This is a replay queue operation to allow existing local ops to
 * complete, and to ease the implementation. See comments in {@link
 * MinimalFolder.close_async}.
 */
private class Convey.ImapEngine.UserClose : Convey.ImapEngine.ReplayOperation {

    /** Determines the state of the close operation. */
    public Trillian is_closing = Trillian.UNKNOWN;

    private MinimalFolder owner;
    private Cancellable? cancellable;


    public UserClose(MinimalFolder owner, Cancellable? cancellable) {
        base("UserClose", Scope.LOCAL_ONLY);
        this.owner = owner;
        this.cancellable = cancellable;
    }

    public override async ReplayOperation.Status replay_local_async() throws Error {
        bool closing = yield this.owner.close_internal(
            Folder.CloseReason.LOCAL_CLOSE,
            Folder.CloseReason.REMOTE_CLOSE,
            this.cancellable
        );
        this.is_closing = Trillian.from_boolean(closing);
        return ReplayOperation.Status.COMPLETED;
    }

    public override string describe_state() {
        return "is_closing: %s".printf(this.is_closing.to_string());
    }

}
