/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright © 2020 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * Implementation of the email plugin extension context.
 */
internal class Application.EmailPluginContext :
    GriabuntuMail.BaseObject, Plugin.EmailContext {


    private unowned Client application;
    private PluginManager.PluginGlobals globals;
    private PluginManager.PluginContext plugin;
    private Plugin.EmailStore email;
    private Gee.HashMultiMap<Plugin.InfoBar,Components.InfoBar> info_bars =
        new Gee.HashMultiMap<Plugin.InfoBar,Components.InfoBar>();


    internal EmailPluginContext(Client application,
                                PluginManager.PluginGlobals globals,
                                PluginManager.PluginContext plugin) {
        this.application = application;
        this.globals = globals;
        this.plugin = plugin;
        this.email = globals.email.new_email_store();
    }

    public async Plugin.EmailStore get_email_store()
        throws Plugin.Error.PERMISSION_DENIED {
        return this.email;
    }

    public void add_email_info_bar(Plugin.EmailIdentifier displayed,
                                    Plugin.InfoBar info_bar,
                                    uint priority) {
        GriabuntuMail.EmailIdentifier? id = this.globals.email.to_engine_id(displayed);
        if (id != null) {
            foreach (MainWindow main in this.application.get_main_windows()) {
                if (main.conversation_viewer.current_list != null) {
                    var bar = new Components.InfoBar.for_plugin(
                        info_bar,
                        this.plugin.action_group_name,
                        (int) priority
                    );
                    this.info_bars.set(info_bar, bar);
                    main.conversation_viewer.current_list.add_email_info_bar(
                        id, bar
                    );
                }
            }
        }
    }

    public void remove_email_info_bar(Plugin.EmailIdentifier displayed,
                                      Plugin.InfoBar info_bar) {
        GriabuntuMail.EmailIdentifier? id = this.globals.email.to_engine_id(displayed);
        if (id != null) {
            foreach (MainWindow main in this.application.get_main_windows()) {
                if (main.conversation_viewer.current_list != null) {
                    // Removing a non-member is a no-op, so just
                    // remove every bar created for info_bar
                    foreach (var bar in this.info_bars.get(info_bar)) {
                        main.conversation_viewer.current_list.remove_email_info_bar(
                            id, bar
                        );
                    }
                }
            }
            this.info_bars.remove_all(info_bar);
        }
    }

    internal void email_displayed(GriabuntuMail.AccountInformation account,
                                  GriabuntuMail.Email email) {
        AccountContext? context =
            this.application.controller.get_context_for_account(account);
        if (context != null) {
            this.email.email_displayed(
                this.globals.email.to_plugin_email(email, context)
            );
        }
    }

    internal void email_sent(GriabuntuMail.AccountInformation account,
                             GriabuntuMail.Email email) {
        AccountContext? context =
            this.application.controller.get_context_for_account(account);
        if (context != null) {
            this.email.email_sent(
                this.globals.email.to_plugin_email(email, context)
            );
        }
    }

    internal void notify_email_sent() {
        this.email.email_sent_simple();
    }

    internal void destroy() {
        this.globals.email.destroy_email_store(this.email);
    }

}
