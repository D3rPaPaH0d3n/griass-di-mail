/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * Utility functions for GIO objects.
 */
namespace GioUtil {

    public const string GRIABUNTU_MAIL_RESOURCE_PREFIX = "/io/github/d3rpapah0d3n/GriabuntuMail/";

    /**
     * Creates a GTK builder given the name of a GResource.
     *
     * The given `name` will automatically have
     * `GRIABUNTU_MAIL_RESOURCE_PREFIX` pre-pended to it.
     */
    public Gtk.Builder create_builder(string name) {
        Gtk.Builder builder = new Gtk.Builder();
        try {
            builder.add_from_resource(GRIABUNTU_MAIL_RESOURCE_PREFIX + name);
        } catch(GLib.Error error) {
            critical("Unable load GResource \"%s\" for Gtk.Builder: %s".printf(
                name, error.message
            ));
        }
        return builder;
    }

    /**
     * Loads a GResource file as a string.
     *
     * The given `name` will automatically have
     * `GRIABUNTU_MAIL_RESOURCE_PREFIX` pre-pended to it.
     */
    public string read_resource(string name) throws Error {
        InputStream input_stream = resources_open_stream(
            GRIABUNTU_MAIL_RESOURCE_PREFIX + name,
            ResourceLookupFlags.NONE
        );
        DataInputStream data_stream = new DataInputStream(input_stream);
        size_t length;
        return data_stream.read_upto("\0", 1, out length);
    }

}
