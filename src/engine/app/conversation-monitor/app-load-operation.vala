/*
 * Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * Loads a specific email all the way to the end of the vector.
 */
private class Convey.App.LoadOperation : ConversationOperation {


    private EmailIdentifier to_load;
    private Nonblocking.Spinlock completed = new Nonblocking.Spinlock();


    public LoadOperation(ConversationMonitor monitor,
                         EmailIdentifier to_load,
                         GLib.Cancellable cancellable) {
        base(monitor);
        this.to_load = to_load;
        this.completed = new Nonblocking.Spinlock(cancellable);
    }

    public override async void execute_async()
        throws GLib.Error {
        Convey.EmailIdentifier? lowest_known = this.monitor.window_lowest;
        if (lowest_known == null ||
            this.to_load.natural_sort_comparator(lowest_known) < 0) {
            // Note the further back to_load is, the more expensive
            // this will be.
            debug("Loading messages into %s",
                  this.monitor.base_folder.to_string());
            yield this.monitor.load_by_id_async(
                this.to_load, int.MAX, Folder.ListFlags.OLDEST_TO_NEWEST
            );
        } else {
            debug("Not loading messages in %s",
                  this.monitor.base_folder.to_string());
        }

        this.completed.notify();
    }

    public async void wait_until_complete(GLib.Cancellable cancellable)
        throws GLib.Error {
        yield this.completed.wait_async(cancellable);
    }

}
