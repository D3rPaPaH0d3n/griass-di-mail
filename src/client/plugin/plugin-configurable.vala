/*
 * Copyright © 2026 Isak Samsten <isak@samsten.se>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

/**
 * Optional preferences entry point for an active plugin.
 *
 * Configuration is not available while the plugin is inactive.
 */
public interface Plugin.Configurable : PluginBase {

    public abstract Adw.Dialog present_preferences(Gtk.Widget parent)
        throws GLib.Error;

}
