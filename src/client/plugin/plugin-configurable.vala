/*
 * Copyright © 2026 Isak Samsten <isak@samsten.se>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
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
