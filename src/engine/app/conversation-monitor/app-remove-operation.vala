/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2016 Software Freedom Conservancy Inc.
 * Copyright 2019 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

private class GriabuntuMail.App.RemoveOperation : BatchOperation<EmailIdentifier> {


    private Folder source_folder;


    public RemoveOperation(ConversationMonitor monitor,
                           Folder source_folder,
                           Gee.Collection<EmailIdentifier> removed_ids) {
        base(monitor, removed_ids);
        this.source_folder = source_folder;
    }

    public override async void execute_batch(Gee.Collection<EmailIdentifier> batch)
        throws GLib.Error {
        debug("Removing %d messages(s) from %s",
              batch.size, this.source_folder.to_string()
        );

        Gee.Set<Conversation> removed = new Gee.HashSet<Conversation>();
        Gee.MultiMap<Conversation,Email> trimmed =
            new Gee.HashMultiMap<Conversation, GriabuntuMail.Email>();
        this.monitor.conversations.remove_all_emails_by_identifier(
            source_folder.path,
            batch,
            removed,
            trimmed
        );

        this.monitor.removed(
            removed,
            trimmed,
            (this.source_folder == this.monitor.base_folder) ? batch : null
        );

        // Queue an update since many emails may have been removed
        this.monitor.check_window_count();
    }

}
