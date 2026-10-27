/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Downstream modification: 2026-10-26 — session-new tray tracking. */
/* Downstream modification: 2026-10-27 — retain unread arrivals on unrelated flag changes. */
/*
 * Copyright © 2016 Software Freedom Conservancy Inc.
 * Copyright © 2019-2020 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * Implementation of the notification plugin extension context.
 */
internal class Application.NotificationPluginContext :
    GriabuntuMail.BaseObject, Plugin.NotificationContext {


    private const GriabuntuMail.Email.Field REQUIRED_FIELDS  = FLAGS;


    private class ContactStoreImpl : GriabuntuMail.BaseObject, Plugin.ContactStore {


        private Application.ContactStore backing;


        public ContactStoreImpl(Application.ContactStore backing) {
            this.backing = backing;
        }

        public async Gee.Collection<Contact> search(string query,
                                                    uint min_importance,
                                                    uint limit,
                                                    GLib.Cancellable? cancellable
        ) throws GLib.Error {
            return yield this.backing.search(
                query, min_importance, limit, cancellable
            );
        }

        public async Contact load(GriabuntuMail.RFC822.MailboxAddress mailbox,
                                  GLib.Cancellable? cancellable
        ) throws GLib.Error {
            return yield this.backing.load(mailbox, cancellable);
        }

    }


    private class MonitorInformation : GriabuntuMail.BaseObject {

        public GriabuntuMail.Folder folder;
        public AccountContext context;
        public GLib.Cancellable? cancellable = null;
        public Gee.Set<GriabuntuMail.EmailIdentifier> recent_ids =
            new Gee.HashSet<GriabuntuMail.EmailIdentifier>();

        public MonitorInformation(GriabuntuMail.Folder folder,
                                  AccountContext context,
                                  GLib.Cancellable? cancellable) {
            this.folder = folder;
            this.context = context;
            this.cancellable = cancellable;
        }
    }

    public int total_new_messages { get { return this._total_new_messages; } }
    public int _total_new_messages = 0;

    private Gee.Map<GriabuntuMail.Folder,MonitorInformation> folder_information =
        new Gee.HashMap<GriabuntuMail.Folder,MonitorInformation>();

    private unowned Client application;
    private PluginManager.PluginGlobals globals;
    private PluginManager.PluginContext plugin;


    internal NotificationPluginContext(Client application,
                                       PluginManager.PluginGlobals globals,
                                       PluginManager.PluginContext plugin) {
        this.application = application;
        this.globals = globals;
        this.plugin = plugin;
    }

    public async Plugin.ContactStore get_contacts_for_folder(Plugin.Folder source)
        throws Plugin.Error.NOT_FOUND, Plugin.Error.PERMISSION_DENIED {
        GriabuntuMail.Folder? folder = this.globals.folders.to_engine_folder(source);
        AccountContext? context = null;
        if (folder != null) {
            context = to_account_context(source);
        }
        if (context == null) {
            throw new Plugin.Error.NOT_FOUND(
                "No account for folder: %s", source.display_name
            );
        }
        return new ContactStoreImpl(context.contacts);
    }

    /**
     * Determines if notifications should be made for a specific folder.
     *
     * Notification plugins should call this to first before
     * displaying a "new mail" notification for mail in a specific
     * folder. It will return true for any monitored folder that is
     * not currently visible in the currently focused main window, if
     * any.
     */
    public bool should_notify_new_messages(Plugin.Folder target) {
        // Don't show notifications if the top of a monitored folder's
        // conversations are visible. That is, if there is a main
        // window, it's focused, the folder is selected, and the
        // conversation list is at the top.
        GriabuntuMail.Folder? folder = this.globals.folders.to_engine_folder(target);
        if (folder == null || !this.folder_information.has_key(folder)) {
            return false;
        }
        MainWindow? window = this.application.last_active_main_window;
        return (
            window == null ||
            !window.is_active ||
            window.selected_folder != folder ||
            window.conversation_list_view.scrolled_window.vadjustment.value > 0.0
        );
    }

    /**
     * Returns the new message count for a specific folder.
     *
     * The context must have already been requested to monitor the
     * folder by a call to {@link start_monitoring_folder}.
     */
    public int get_new_message_count(Plugin.Folder target)
        throws Plugin.Error.NOT_FOUND {
        GriabuntuMail.Folder? folder = this.globals.folders.to_engine_folder(target);
        MonitorInformation? info = null;
        if (folder != null) {
            info = folder_information.get(folder);
        }
        if (info == null) {
            throw new Plugin.Error.NOT_FOUND(
                "No such folder: %s", folder.path.to_string()
            );
        }
        return info.recent_ids.size;
    }

    /**
     * Starts monitoring a folder for new messages.
     *
     * Notification plugins should call this to start the context
     * recording new messages for a specific folder.
     */
    public void start_monitoring_folder(Plugin.Folder target) {
        GriabuntuMail.Folder? folder = this.globals.folders.to_engine_folder(target);
        AccountContext? context = null;
        if (folder != null) {
            context = to_account_context(target);
        }
        if (folder != null &&
            context != null &&
            !this.folder_information.has_key(folder)) {
            folder.email_locally_appended.connect(on_email_locally_appended);
            folder.email_flags_changed.connect(on_email_flags_changed);
            folder.email_removed.connect(on_email_removed);

            this.folder_information.set(
                folder, new MonitorInformation(folder, context, context.cancellable)
            );
        }
    }

    /** Stops monitoring a folder for new messages. */
    public void stop_monitoring_folder(Plugin.Folder target) {
        GriabuntuMail.Folder? folder = this.globals.folders.to_engine_folder(target);
        if (folder != null) {
            remove_folder(folder);
        }
    }

    /** Determines if a folder is currently being monitored. */
    public bool is_monitoring_folder(Plugin.Folder target) {
        return this.folder_information.has_key(
            this.globals.folders.to_engine_folder(target)
        );
    }

    internal void destroy() {
        // Get an array so the loop does not blow up when removing values.
        foreach (GriabuntuMail.Folder monitored in this.folder_information.keys.to_array()) {
            remove_folder(monitored);
        }
    }

    internal void clear_new_messages(GriabuntuMail.Folder location,
                                     Gee.Set<GriabuntuMail.App.Conversation>? visible) {
        MonitorInformation? info = this.folder_information.get(location);
        if (info != null) {
            foreach (GriabuntuMail.App.Conversation conversation in visible) {
                if (GriabuntuMail.traverse(
                        conversation.get_email_ids()
                    ).any((id) => info.recent_ids.contains(id))) {
                    Gee.Set<GriabuntuMail.EmailIdentifier> old_ids = info.recent_ids;
                    info.recent_ids = new Gee.HashSet<GriabuntuMail.EmailIdentifier>();
                    update_count(info, false, old_ids);
                    break;
                }
            }
        }
    }

    private void new_messages(MonitorInformation info,
                              Gee.Collection<GriabuntuMail.Email> emails) {
        Gee.Collection<GriabuntuMail.EmailIdentifier> added =
            new Gee.HashSet<GriabuntuMail.EmailIdentifier>();
        foreach (GriabuntuMail.Email email in emails) {
            if (email.email_flags.is_unread() &&
                info.recent_ids.add(email.id)) {
                added.add(email.id);
            }
        }
        if (added.size > 0) {
            update_count(info, true, added);
        }
    }

    private void retire_new_messages(GriabuntuMail.Folder folder,
        Gee.Collection<GriabuntuMail.EmailIdentifier> email_ids
    ) {
        MonitorInformation info = folder_information.get(folder);
        Gee.Collection<GriabuntuMail.EmailIdentifier> removed =
            new Gee.HashSet<GriabuntuMail.EmailIdentifier>();
        foreach (GriabuntuMail.EmailIdentifier email_id in email_ids) {
            if (info.recent_ids.remove(email_id)) {
                removed.add(email_id);
            }
        }

        if (removed.size > 0) {
            update_count(info, false, removed);
        }
    }

    private AccountContext? to_account_context(Plugin.Folder folder) {
        var account = folder.account as PluginManager.AccountImpl;
        return account != null ? account.backing : null;
    }

    private void emit_email_seen(GriabuntuMail.Folder folder,
                                 Gee.Collection<GriabuntuMail.EmailIdentifier> email_ids) {
        MonitorInformation? info = this.folder_information.get(folder);
        if (info != null && !email_ids.is_empty) {
            email_seen(
                this.globals.folders.to_plugin_folder(folder),
                this.globals.email.to_plugin_ids(email_ids, info.context)
            );
        }
    }

    private void update_count(MonitorInformation info,
                              bool arrived,
                              Gee.Collection<GriabuntuMail.EmailIdentifier> delta) {
        Plugin.Folder folder =
            this.globals.folders.to_plugin_folder(info.folder);
        if (arrived) {
            this._total_new_messages += delta.size;
            new_messages_arrived(
                folder,
                info.recent_ids.size,
                this.globals.email.to_plugin_ids(delta, info.context)
            );
        } else {
            this._total_new_messages -= delta.size;
            new_messages_retired(
                folder, info.recent_ids.size
            );
        }
        notify_property("total-new-messages");
        update_tray(info);
    }

    private void update_tray(MonitorInformation info) {
        // Both notification plugins monitor these folders. Publish only the
        // auto-loaded desktop context, never sum duplicate monitors.
        if (this.plugin.info.get_module_name() != "desktop-notifications") return;
        var targets = new Gee.HashMap<GriabuntuMail.EmailIdentifier,GLib.Variant>();
        foreach (var plugin_id in this.globals.email.to_plugin_ids(info.recent_ids, info.context)) {
            var id = plugin_id as EmailStoreFactory.IdImpl;
            if (id != null) targets.set(id.backing, id.to_variant());
        }
        this.application.update_tray_new_mail(
            info.folder.account.information.id + ":" + info.folder.path.to_variant().print(false),
            info.folder, targets
        );
    }

    private void remove_folder(GriabuntuMail.Folder target) {
        MonitorInformation? info = this.folder_information.get(target);
        if (info != null) {
            target.email_locally_appended.disconnect(on_email_locally_appended);
            target.email_flags_changed.disconnect(on_email_flags_changed);
            target.email_removed.disconnect(on_email_removed);

            if (!info.recent_ids.is_empty) {
                this._total_new_messages -= info.recent_ids.size;
                notify_property("total-new-messages");
            }

            this.folder_information.unset(target);
            info.recent_ids.clear();
            update_tray(info);
        }

    }

    private async void do_process_new_email(
        GriabuntuMail.Folder folder,
        Gee.Collection<GriabuntuMail.EmailIdentifier> email_ids
    ) {
        MonitorInformation info = this.folder_information.get(folder);
        if (info != null) {
            Gee.List<GriabuntuMail.Email>? list = null;
            try {
                list = yield folder.list_email_by_sparse_id_async(
                    email_ids,
                    REQUIRED_FIELDS,
                    NONE,
                    info.cancellable
                );
            } catch (GLib.Error err) {
                warning(
                    "Unable to list new email for notification: %s", err.message
                );
            }
            if (list != null && !list.is_empty) {
                new_messages(info, list);
                return;
            }

            Gee.Collection<GriabuntuMail.EmailIdentifier> added =
                new Gee.HashSet<GriabuntuMail.EmailIdentifier>();
            foreach (GriabuntuMail.EmailIdentifier id in email_ids) {
                if (info.recent_ids.add(id)) {
                    added.add(id);
                }
            }
            if (added.size > 0) {
                update_count(info, true, added);
            } else {
                warning(
                    "%d new emails, but none could be listed for notification",
                    email_ids.size
                );
            }
        }
    }

    private void on_email_locally_appended(GriabuntuMail.Folder folder,
        Gee.Collection<GriabuntuMail.EmailIdentifier> email_ids) {
        do_process_new_email.begin(folder, email_ids);
    }

    private void on_email_flags_changed(GriabuntuMail.Folder folder,
        Gee.Map<GriabuntuMail.EmailIdentifier, GriabuntuMail.EmailFlags> ids) {
        // Star and other flag changes do not make an unread arrival old.
        retire_new_messages(
            folder,
            GriabuntuMail.traverse(ids.keys).filter(
                (id) => !ids.get(id).is_unread() || ids.get(id).is_deleted()
            ).to_array_list()
        );
        emit_email_seen(
            folder,
            GriabuntuMail.traverse(ids.keys).filter(
                (id) => !ids.get(id).is_unread()
            ).to_array_list()
        );
    }

    private void on_email_removed(GriabuntuMail.Folder folder,
                                  Gee.Collection<GriabuntuMail.EmailIdentifier> ids) {
        retire_new_messages(folder, ids);
        emit_email_seen(folder, ids);
    }

}
