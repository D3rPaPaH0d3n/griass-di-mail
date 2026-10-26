/*
 * Copyright 2016 Software Freedom Conservancy Inc.
 * Copyright 2018-2019 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * An internal operation used to keep conversations up to date.
 *
 * Classes implementing this interface are used by {@link
 * ConversationMonitor} to asynchronously keep conversations up to
 * date as messages are added to, updated, and removed from folders.
 */
internal abstract class Convey.App.ConversationOperation : BaseObject {


    /** Determines if multiple instances of this operation can be queued. */
    public bool allow_duplicates { get; private set; }

    /** The monitor this operation will be applied to. */
    protected weak ConversationMonitor? monitor = null;


    protected ConversationOperation(ConversationMonitor? monitor,
                                    bool allow_duplicates = true) {
        this.monitor = monitor;
        this.allow_duplicates = allow_duplicates;
    }

    public abstract async void execute_async() throws Error;

}

/**
 * An operation that executes on a collection in batches.
 */
internal abstract class Convey.App.BatchOperation<T> : ConversationOperation {


    private const int BATCH_MAX_N = 100;


    private Gee.Collection<T> full;


    protected BatchOperation(ConversationMonitor? monitor,
                             Gee.Collection<T> full) {
        base(monitor, true);
        this.full = full;
    }

    public override async void execute_async() throws GLib.Error {
        Gee.Collection<T>? batch = new Gee.LinkedList<T>();
        foreach (T element in this.full) {
            batch.add(element);

            if (batch.size == BATCH_MAX_N) {
                yield execute_batch(batch);
                batch = new Gee.LinkedList<T>();
            }
        }

        if (!batch.is_empty) {
            yield execute_batch(batch);
        }
    }

    public abstract async void execute_batch(Gee.Collection<T> batch)
        throws GLib.Error;

}
