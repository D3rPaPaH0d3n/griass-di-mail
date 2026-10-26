/* Licensed under LGPL-2.1-or-later. See COPYING. */

/* In-memory application boundaries for test-notification-flags only.
 * The real notification context, plugin interfaces, engine flags/folder signals
 * and tray model are compiled into that executable, NOT the client library.
 * No GTK application, plugin loader, contacts backend or mail store is started.
 */
namespace Plugin {
    public abstract class PluginBase : Convey.BaseObject {}
}

namespace Application {
    public class Contact : Convey.BaseObject {}

    public class ContactStore : Convey.BaseObject {
        public async Gee.Collection<Contact> search(
            string query, uint min_importance, uint limit,
            GLib.Cancellable? cancellable
        ) throws GLib.Error {
            throw new GLib.IOError.NOT_SUPPORTED("No contacts in this fixture");
        }

        public async Contact load(Convey.RFC822.MailboxAddress mailbox,
                                  GLib.Cancellable? cancellable) throws GLib.Error {
            throw new GLib.IOError.NOT_SUPPORTED("No contacts in this fixture");
        }
    }

    public class AccountContext : Convey.BaseObject {
        public GLib.Cancellable cancellable = new GLib.Cancellable();
        public ContactStore contacts = new ContactStore();
    }

    public class MainWindow : GLib.Object {
        public bool is_active = false;
        public Convey.Folder? selected_folder = null;
        public ConversationListView conversation_list_view = new ConversationListView();
    }

    public class ConversationListView : GLib.Object {
        public ScrolledWindow scrolled_window = new ScrolledWindow();
    }

    public class ScrolledWindow : GLib.Object {
        public Adjustment vadjustment = new Adjustment();
    }

    public class Adjustment : GLib.Object {
        public double value = 0.0;
    }

    public class Client : GLib.Object {
        public MainWindow? last_active_main_window = null;
        internal TrayMailModel tray = new TrayMailModel();

        internal void update_tray_new_mail(
            string key, Convey.Folder folder,
            Gee.Map<Convey.EmailIdentifier,GLib.Variant> targets
        ) {
            this.tray.set_folder(key, targets.values.to_array());
        }
    }

    public class PluginManager : GLib.Object {
        public class AccountImpl : Convey.BaseObject, Plugin.Account {
            public string display_name { get { return "Synthetic account"; } }
            public AccountContext backing = new AccountContext();
        }

        public class PluginGlobals : GLib.Object {
            public FolderStoreFactory folders = new FolderStoreFactory();
            public EmailStoreFactory email = new EmailStoreFactory();
        }

        public class PluginContext : GLib.Object {
            public ModuleInfo info = new ModuleInfo();
        }

        public class ModuleInfo : GLib.Object {
            public string get_module_name() { return "desktop-notifications"; }
        }
    }

    public class FolderStoreFactory : GLib.Object {
        public class FolderImpl : Convey.BaseObject, Plugin.Folder {
            public string persistent_id { get { return "synthetic:inbox"; } }
            public string display_name { get { return "Synthetic Inbox"; } }
            public Convey.Folder.SpecialUse used_as { get { return INBOX; } }
            public Plugin.Account? account { get { return this.owner; } }
            public Convey.Folder backing;
            private PluginManager.AccountImpl owner = new PluginManager.AccountImpl();

            public FolderImpl(Convey.Folder backing) { this.backing = backing; }
            public GLib.Variant to_variant() { return this.backing.path.to_variant(); }
        }

        public FolderImpl? folder = null;
        public Convey.Folder? to_engine_folder(Plugin.Folder folder) {
            return ((FolderImpl) folder).backing;
        }
        public Plugin.Folder? to_plugin_folder(Convey.Folder folder) {
            return this.folder != null && this.folder.backing == folder ? this.folder : null;
        }
    }

    public class EmailStoreFactory : GLib.Object {
        public class IdImpl : Convey.BaseObject,
            Gee.Hashable<Plugin.EmailIdentifier>, Plugin.EmailIdentifier {
            public Convey.EmailIdentifier backing;
            public Plugin.Account account { get { return this.owner; } }
            private PluginManager.AccountImpl owner = new PluginManager.AccountImpl();

            public IdImpl(Convey.EmailIdentifier backing) { this.backing = backing; }
            public uint hash() { return this.backing.hash(); }
            public bool equal_to(Plugin.EmailIdentifier other) {
                var id = other as IdImpl;
                return id != null && this.backing.equal_to(id.backing);
            }
            public GLib.Variant to_variant() {
                return new GLib.Variant("(sv)", "synthetic", this.backing.to_variant());
            }
        }

        public Gee.Collection<Plugin.EmailIdentifier> to_plugin_ids(
            Gee.Collection<Convey.EmailIdentifier> ids, AccountContext context
        ) {
            var result = new Gee.ArrayList<Plugin.EmailIdentifier>();
            foreach (var id in ids) result.add(new IdImpl(id));
            return result;
        }
    }
}
