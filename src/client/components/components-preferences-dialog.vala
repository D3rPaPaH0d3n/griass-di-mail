/*
 * Copyright 2016 Software Freedom Conservancy Inc.
 * Copyright 2019 Michael Gratton <mike@vee.net>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

[GtkTemplate (ui = "/net/donnybeelo/Convey/components-preferences-dialog.ui")]
public class Components.PreferencesDialog : Adw.PreferencesDialog {

    [GtkChild] private unowned Adw.SwitchRow autoselect_row;
    [GtkChild] private unowned Adw.SwitchRow display_preview_row;
    [GtkChild] private unowned Adw.SwitchRow display_participants_row;
    [GtkChild] private unowned Adw.SwitchRow display_subject_row;
    [GtkChild] private unowned Adw.SwitchRow display_recipient_aliases_row;
    [GtkChild] private unowned Adw.SwitchRow display_contact_pictures_row;
    [GtkChild] private unowned Adw.PreferencesGroup conversation_list_group;
    [GtkChild] private unowned Adw.NavigationPage conversation_list_subpage;
    [GtkChild] private unowned Gtk.Button conversation_list_reset_button;
    [GtkChild] private unowned Adw.SwitchRow remember_last_inbox_row;
    [GtkChild] private unowned Adw.ComboRow startup_inbox_row;
    [GtkChild] private unowned Adw.SwitchRow local_starred_folder_row;
    [GtkChild] private unowned Adw.SwitchRow single_key_shortcuts_row;
    [GtkChild] private unowned Adw.SwitchRow startup_notifications_row;
    [GtkChild] private unowned Adw.SwitchRow trust_images_row;
    [GtkChild] private unowned Adw.SwitchRow unverified_images_row;
    [GtkChild] private unowned Adw.SwitchRow unset_html_colors_row;
    [GtkChild] private unowned Adw.SwitchRow custom_proxy_row;
    [GtkChild] private unowned Adw.EntryRow proxy_uri_row;

    [GtkChild] private unowned Adw.PreferencesGroup plugins_group;

    private class PluginRow : Adw.ActionRow {

        private Peas.PluginInfo plugin;
        private Application.PluginManager plugins;
        private Gtk.Switch sw = new Gtk.Switch();
        private Gtk.Button configure = new Gtk.Button.from_icon_name(
            "emblem-system-symbolic"
        );
        private Adw.Dialog? preferences = null;
        private ulong activated_id;
        private ulong unloading_id;
        private ulong deactivated_id;
        private ulong error_id;


        public PluginRow(Peas.PluginInfo plugin,
                         Application.PluginManager plugins) {
            this.plugin = plugin;
            this.plugins = plugins;

            this.sw.active = plugin.is_loaded();
            this.sw.notify["active"].connect_after(() => update_plugin());
            this.sw.valign = CENTER;

            var label = _("Configure %s").printf(this.plugin.get_name());
            this.configure.valign = CENTER;
            this.configure.tooltip_text = label;
            this.configure.update_property(
                Gtk.AccessibleProperty.LABEL, label, -1
            );
            this.configure.clicked.connect(on_configure);
            this.add_suffix(this.configure);
            this.configure.visible = this.plugins.has_preferences(this.plugin);

            this.title = plugin.get_name();
            this.subtitle = plugin.get_description();
            this.activatable_widget = this.sw;
            this.add_suffix(this.sw);

            this.activated_id = plugins.plugin_activated.connect((info) => {
                    if (this.plugin == info) {
                        this.sw.active = true;
                        this.configure.visible = this.plugins.has_preferences(this.plugin);
                    }
                });
            this.unloading_id = plugins.plugin_unloading.connect((info) => {
                    if (this.plugin == info) {
                        close_preferences();
                        this.configure.visible = false;
                    }
                });
            this.deactivated_id = plugins.plugin_deactivated.connect((info) => {
                    if (this.plugin == info) {
                        close_preferences();
                        this.sw.active = false;
                        this.configure.visible = false;
                    }
                });
            this.error_id = plugins.plugin_error.connect((info) => {
                    if (this.plugin == info) {
                        close_preferences();
                        this.sw.active = false;
                        this.sw.sensitive = false;
                        this.configure.visible = false;
                    }
                });
        }

        protected override void dispose() {
            close_preferences();
            disconnect_handler(ref this.activated_id);
            disconnect_handler(ref this.unloading_id);
            disconnect_handler(ref this.deactivated_id);
            disconnect_handler(ref this.error_id);
            base.dispose();
        }

        private void disconnect_handler(ref ulong id) {
            if (id != 0) {
                GLib.SignalHandler.disconnect(this.plugins, id);
                id = 0;
            }
        }

        private void close_preferences() {
            if (this.preferences != null) {
                this.preferences.close();
                this.preferences = null;
            }
        }

        private void on_configure() {
            if (this.preferences != null) {
                return;
            }
            try {
                var dialog = this.plugins.present_preferences(
                    this.plugin, this
                );
                this.preferences = dialog;
                dialog.closed.connect(() => {
                    if (this.preferences == dialog) {
                        this.preferences = null;
                    }
                });
            } catch (GLib.Error err) {
                warning(
                    "Plugin %s preferences could not be opened: %s",
                    this.plugin.get_name(), err.message
                );
                var dialog = this.get_ancestor(typeof(Adw.PreferencesDialog))
                    as Adw.PreferencesDialog;
                if (dialog != null) {
                    dialog.add_toast(new Adw.Toast(
                        _("Could not open plugin preferences")
                    ));
                }
            }
        }

        private void update_plugin() {
            if (this.sw.active && !this.plugin.is_loaded()) {
                bool loaded = false;
                try {
                    loaded = this.plugins.load_optional(this.plugin);
                } catch (GLib.Error err) {
                    warning(
                        "Plugin %s not able to be loaded: %s",
                        plugin.get_name(), err.message
                    );
                }
                if (!loaded) {
                    this.sw.active = false;
                }
            } else if (!sw.active && this.plugin.is_loaded()) {
                bool unloaded = false;
                try {
                    unloaded = this.plugins.unload_optional(this.plugin);
                } catch (GLib.Error err) {
                    warning(
                        "Plugin %s not able to be loaded: %s",
                        plugin.get_name(), err.message
                    );
                }
                if (!unloaded) {
                    this.sw.active = true;
                }
            }
        }

    }



    /** Returns the window's associated client application instance. */
    public Application.Client? application { get; construct set; }

    private Application.PluginManager plugins;

    private string[] startup_inbox_ids = {};

    private const string[] CONVERSATION_LIST_FIELDS = {
        "participants", "subject", "preview"
    };

    public PreferencesDialog(Application.Client application,
                             Application.PluginManager plugins) {
        Object(application: application);
        this.plugins = plugins;

        setup_general_pane();
        setup_plugin_pane();
    }

    private void setup_general_pane() {
        Application.Configuration config = this.application.config;
        config.bind(
            Application.Configuration.AUTOSELECT_KEY,
            this.autoselect_row,
            "active"
        );
        config.bind(
            Application.Configuration.DISPLAY_PREVIEW_KEY,
            this.display_preview_row,
            "active"
        );
        config.bind(
            Application.Configuration.DISPLAY_PARTICIPANTS_KEY,
            this.display_participants_row,
            "active"
        );
        config.bind(
            Application.Configuration.DISPLAY_SUBJECT_KEY,
            this.display_subject_row,
            "active"
        );
        setup_conversation_list_order();
        config.bind(
            Application.Configuration.DISPLAY_RECIPIENT_ALIASES_KEY,
            this.display_recipient_aliases_row,
            "active"
        );
        config.bind(
            Application.Configuration.DISPLAY_CONTACT_PICTURES_KEY,
            this.display_contact_pictures_row,
            "active"
        );
        config.bind(
            Application.Configuration.SINGLE_KEY_SHORTCUTS,
            this.single_key_shortcuts_row,
            "active"
        );
        config.bind(
            Application.Configuration.RUN_IN_BACKGROUND_KEY,
            this.startup_notifications_row,
            "active"
        );
        config.bind(
            Application.Configuration.UNSET_HTML_COLORS,
            this.unset_html_colors_row,
            "active"
        );
        config.bind(
            Application.Configuration.REMEMBER_LAST_INBOX,
            this.remember_last_inbox_row,
            "active"
        );
        this.remember_last_inbox_row.bind_property(
            "active",
            this.startup_inbox_row,
            "sensitive",
            INVERT_BOOLEAN | SYNC_CREATE
        );
        setup_startup_inbox_row();
        config.bind_with_mapping(
            Application.Configuration.IMAGES_TRUSTED_DOMAINS,
            this.trust_images_row,
            "active",
            (GLib.SettingsBindGetMappingShared) settings_trust_images_getter,
            (GLib.SettingsBindSetMappingShared) settings_trust_images_setter
        );
        config.bind(
            Application.Configuration.LOAD_UNVERIFIED_IMAGES,
            this.unverified_images_row,
            "active"
        );
        this.trust_images_row.bind_property(
            "active",
            this.unverified_images_row,
            "sensitive",
            SYNC_CREATE
        );
        config.bind(
            Application.Configuration.LOCAL_STARRED_FOLDER,
            this.local_starred_folder_row,
            "active"
        );
        config.bind(
            Application.Configuration.USE_CUSTOM_PROXY,
            this.custom_proxy_row,
            "active"
        );
        this.custom_proxy_row.bind_property(
            "active",
            this.proxy_uri_row,
            "sensitive",
            SYNC_CREATE
        );
        this.proxy_uri_row.text = config.proxy_uri;
        this.proxy_uri_row.apply.connect(() => {
            config.settings.set_string(
                Application.Configuration.PROXY_URI,
                this.proxy_uri_row.text.strip()
            );
        });
    }

    private void setup_startup_inbox_row() {
        var accounts = new Gee.ArrayList<Convey.AccountInformation>();
        try {
            foreach (var account in this.application.engine.get_accounts()) {
                accounts.add(account.information);
            }
        } catch (GLib.Error error) {
            debug("Error listing accounts: %s", error.message);
        }

        var names = new Gtk.StringList(null);
        if (accounts.size > 1) {
            this.startup_inbox_ids += Application.Configuration.ALL_INBOXES;
            names.append(_("All Inboxes"));
        }
        foreach (var info in accounts) {
            this.startup_inbox_ids += info.id;
            names.append(info.display_name);
        }
        this.startup_inbox_row.model = names;

        string current = this.application.config.get_last_inbox();
        for (int i = 0; i < this.startup_inbox_ids.length; i++) {
            if (this.startup_inbox_ids[i] == current) {
                this.startup_inbox_row.selected = i;
                break;
            }
        }

        this.startup_inbox_row.notify["selected"].connect(() => {
            uint selected = this.startup_inbox_row.selected;
            if (selected < this.startup_inbox_ids.length) {
                this.application.config.set_last_inbox(
                    this.startup_inbox_ids[selected]
                );
            }
        });
    }

    [GtkCallback]
    private void on_conversation_list_activated() {
        push_subpage(this.conversation_list_subpage);
    }

    [GtkCallback]
    private void on_conversation_list_reset() {
        foreach (string key in new string[] {
                     Application.Configuration.CONVERSATION_LIST_ORDER_KEY,
                     Application.Configuration.DISPLAY_PARTICIPANTS_KEY,
                     Application.Configuration.DISPLAY_SUBJECT_KEY,
                     Application.Configuration.DISPLAY_PREVIEW_KEY
                 }) {
            this.application.config.settings.reset(key);
        }
        show_conversation_list_order(get_conversation_list_order());
    }

    private void update_conversation_list_reset() {
        bool all_shown = true;
        foreach (string field in CONVERSATION_LIST_FIELDS) {
            all_shown &= get_conversation_list_row(field).active;
        }
        this.conversation_list_reset_button.sensitive = !all_shown ||
            string.joinv(",", get_conversation_list_order()) !=
            string.joinv(",", CONVERSATION_LIST_FIELDS);
    }

    private void setup_conversation_list_order() {
        foreach (string field in CONVERSATION_LIST_FIELDS) {
            var row = get_conversation_list_row(field);
            row.notify["active"].connect(update_conversation_list_reset);
            row.add_prefix(new Gtk.Image.from_icon_name("list-drag-handle-symbolic"));

            double hot_x = 0, hot_y = 0;
            var drag = new Gtk.DragSource();
            drag.actions = MOVE;
            drag.prepare.connect((x, y) => {
                hot_x = x;
                hot_y = y;
                return new Gdk.ContentProvider.for_value(field);
            });
            drag.drag_begin.connect(() => {
                drag.set_icon(new Gtk.WidgetPaintable(row), (int) hot_x, (int) hot_y);
            });
            row.add_controller(drag);

            var drop = new Gtk.DropTarget(typeof(string), MOVE);
            drop.drop.connect((value) => {
                move_conversation_list_field(value.get_string(), field);
                return true;
            });
            row.add_controller(drop);
        }
        show_conversation_list_order(get_conversation_list_order());
    }

    private string[] get_conversation_list_order() {
        string[] order = {};
        foreach (string field in this.application.config.settings.get_strv(
                     Application.Configuration.CONVERSATION_LIST_ORDER_KEY
                 )) {
            if (field in CONVERSATION_LIST_FIELDS && !(field in order)) {
                order += field;
            }
        }
        foreach (string field in CONVERSATION_LIST_FIELDS) {
            if (!(field in order)) {
                order += field;
            }
        }
        return order;
    }

    private void move_conversation_list_field(string field, string target) {
        var order = new Gee.ArrayList<string>.wrap(get_conversation_list_order());
        int to = order.index_of(target);
        order.remove(field);
        order.insert(to, field);
        string[] fields = {};
        foreach (string item in order) {
            fields += item;
        }
        this.application.config.settings.set_strv(
            Application.Configuration.CONVERSATION_LIST_ORDER_KEY, fields
        );
        show_conversation_list_order(fields);
    }

    private void show_conversation_list_order(string[] order) {
        update_conversation_list_reset();
        foreach (string field in order) {
            Adw.SwitchRow row = get_conversation_list_row(field);
            this.conversation_list_group.remove(row);
            this.conversation_list_group.add(row);
        }
    }

    private Adw.SwitchRow get_conversation_list_row(string field) {
        switch (field) {
        case "participants":
            return this.display_participants_row;
        case "subject":
            return this.display_subject_row;
        default:
            return this.display_preview_row;
        }
    }

    private void setup_plugin_pane() {
        foreach (Peas.PluginInfo plugin in
                 this.plugins.get_optional_plugins()) {
            this.plugins_group.add(new PluginRow(plugin, this.plugins));
        }
    }

    private static bool settings_trust_images_getter(GLib.Value value, GLib.Variant variant, void* user_data) {
        var domains = variant.get_strv();
        value.set_boolean(domains.length > 0 && domains[0] == "*");
        return true;
    }

    private static GLib.Variant settings_trust_images_setter(GLib.Value value, GLib.VariantType expected_type, void* user_data) {
        var trusted = value.get_boolean();
        string[] values = {};
        if (trusted)
            values += "*";
        return new GLib.Variant.strv(values);
    }
}
