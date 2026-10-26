/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * Displays a dialog for collecting the user's password, without allowing them to change their
 * other data.
 */
[GtkTemplate (ui = "/net/donnybeelo/Convey/password-dialog.ui")]
public class PasswordDialog : Adw.AlertDialog {

    [GtkChild] private unowned Adw.PreferencesGroup prefs_group;
    [GtkChild] private unowned Adw.ActionRow username_row;
    [GtkChild] private unowned Adw.PasswordEntryRow password_row;
    [GtkChild] private unowned Adw.SwitchRow remember_password_row;

    public PasswordDialog(Gtk.Window? parent,
                          Convey.AccountInformation account,
                          Convey.ServiceInformation service,
                          Convey.Credentials? credentials) {
        if (credentials != null) {
            this.username_row.subtitle = credentials.user;
            this.password_row.text = credentials.token ?? "";
        }
        this.remember_password_row.active = service.remember_password;

        if ((service.protocol == Convey.Protocol.SMTP)) {
            this.prefs_group.title = _("SMTP Credentials");
        }

        refresh_ok_button_sensitivity();
        this.password_row.changed.connect(refresh_ok_button_sensitivity);
    }

    private void refresh_ok_button_sensitivity() {
        string password = this.password_row.text;
        set_response_enabled("authenticate", !Convey.String.is_empty_or_whitespace(password));
    }

    public async string? get_password(Gtk.Window? parent,
                                      out bool remember_password) {
        string response = yield choose(parent, null);

        if (response == "cancel") {
            remember_password = false;
            return null;
        }

        remember_password = this.remember_password_row.active;
        string password = this.password_row.text;
        close();
        return password;
    }
}

