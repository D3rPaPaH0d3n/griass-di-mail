/*
 * Copyright 2016 Software Freedom Conservancy Inc.
 * Copyright 2019 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

private class Convey.App.AppendOperation : BatchOperation<EmailIdentifier> {


    public AppendOperation(ConversationMonitor monitor,
                           Gee.Collection<EmailIdentifier> appended_ids) {
        base(monitor, appended_ids);
    }

    public override async void execute_batch(Gee.Collection<EmailIdentifier> batch)
        throws GLib.Error {
        debug("Appending %d message(s) to %s",
              batch.size, this.monitor.base_folder.to_string());

        yield this.monitor.load_by_sparse_id(batch);
    }

}
