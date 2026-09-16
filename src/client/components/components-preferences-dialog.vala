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
    [GtkChild] private unowned Adw.SwitchRow remember_last_inbox_row;
    [GtkChild] private unowned Adw.ComboRow startup_inbox_row;
    [GtkChild] private unowned Adw.SwitchRow single_key_shortcuts_row;
    [GtkChild] private unowned Adw.SwitchRow startup_notifications_row;
    [GtkChild] private unowned Adw.SwitchRow trust_images_row;
    [GtkChild] private unowned Adw.SwitchRow unset_html_colors_row;

    [GtkChild] private unowned Adw.PreferencesGroup plugins_group;

    private class PluginRow : Adw.ActionRow {

        private Peas.PluginInfo plugin;
        private Application.PluginManager plugins;
        private Gtk.Switch sw = new Gtk.Switch();


        public PluginRow(Peas.PluginInfo plugin,
                         Application.PluginManager plugins) {
            this.plugin = plugin;
            this.plugins = plugins;

            this.sw.active = plugin.is_loaded();
            this.sw.notify["active"].connect_after(() => update_plugin());
            this.sw.valign = CENTER;

            this.title = plugin.get_name();
            this.subtitle = plugin.get_description();
            this.activatable_widget = this.sw;
            this.add_suffix(this.sw);

            plugins.plugin_activated.connect((info) => {
                    if (this.plugin == info) {
                        this.sw.active = true;
                    }
                });
            plugins.plugin_deactivated.connect((info) => {
                    if (this.plugin == info) {
                        this.sw.active = false;
                    }
                });
            plugins.plugin_error.connect((info) => {
                    if (this.plugin == info) {
                        this.sw.active = false;
                        this.sw.sensitive = false;
                    }
                });
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
