/*
 * Copyright © 2017 Software Freedom Conservancy Inc.
 * Copyright © 2021 Michael Gratton <mike@vee.net>
 * Copyright © 2022 Cédric Bellegarde <cedric.bellegarde@adishatz.org>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */


/**
 * The Application HeaderBar
 *
 * @see Application.MainWindow
 */
[GtkTemplate (ui = "/org/gnome/Geary/components-headerbar-application.ui")]
public class Components.ApplicationHeaderBar : Hdy.HeaderBar {

    [GtkChild] private unowned Gtk.MenuButton app_menu_button;
    [GtkChild] private unowned Gtk.Stack refresh_stack;
    [GtkChild] private unowned Gtk.Button refresh_button;
    [GtkChild] private unowned Gtk.Image refresh_image;
    [GtkChild] private unowned Gtk.Spinner spinner;

    /** Fired when the user clicks the refresh button. */
    public signal void refresh_clicked();

    private int busy_count = 0;


    construct {
        Gtk.Builder builder = new Gtk.Builder.from_resource("/org/gnome/Geary/components-menu-application.ui");
        MenuModel app_menu = (MenuModel) builder.get_object("app_menu");

        this.app_menu_button.popover = new Gtk.Popover.from_model(null, app_menu);
        this.refresh_button.clicked.connect(() => refresh_clicked());
    }

    /** Shows the spinner in place of the refresh button while busy. */
    public void push_busy() {
        this.busy_count++;
        this.spinner.start();
        this.refresh_stack.visible_child = this.spinner;
    }

    /** Restores the refresh icon once all busy work has finished. */
    public void pop_busy() {
        this.busy_count = int.max(0, this.busy_count - 1);
        if (this.busy_count == 0) {
            this.spinner.stop();
            this.refresh_stack.visible_child = this.refresh_image;
        }
    }

    /** Ties the busy state to a progress monitor's activity. */
    public void set_progress_monitor(Geary.ProgressMonitor monitor) {
        monitor.start.connect(() => push_busy());
        monitor.finish.connect(() => pop_busy());
    }

    public void show_app_menu() {
        this.app_menu_button.clicked();
    }

}
