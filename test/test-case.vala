/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2020 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/** Base class for Griabuntu Mail unit tests. */
public class TestCase : ValaUnit.TestCase {

    /** GLib.File URI for resources in test/data. */
    public const string RESOURCE_URI = "resource:///io/github/d3rpapah0d3n/GriabuntuMailTest";


    public TestCase(string name) {
        base(name);
    }

    public void delete_file(File parent) throws GLib.Error {
        FileInfo info = parent.query_info(
            "standard::*",
            FileQueryInfoFlags.NOFOLLOW_SYMLINKS
        );

        if (info.get_file_type () == FileType.DIRECTORY) {
            FileEnumerator enumerator = parent.enumerate_children(
                "standard::*",
                FileQueryInfoFlags.NOFOLLOW_SYMLINKS
            );

            info = null;
            while (((info = enumerator.next_file()) != null)) {
                delete_file(parent.get_child(info.get_name()));
            }
        }

        parent.delete();
    }

}