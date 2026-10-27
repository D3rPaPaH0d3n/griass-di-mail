/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2016 Software Freedom Conservancy Inc.
 * Copyright 2018 Michael Gratton <mike@vee.net>.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * Represents a mailbox on an IMAP server.
 *
 * Everything we can glean from an IMAP LIST for a specific folder is
 * encapsulated here. Any information requires the folder to be
 * selected, and hence there is no other information about
 * non-selectable folders that can be obtained.
 *
 * Note the mailbox name is not represented since that may differ
 * based on the client session being used to connect to the server.
 */
internal class GriabuntuMail.Imap.Folder : GriabuntuMail.BaseObject {

    /** The full path to this folder. */
    public FolderPath path { get; private set; }

    /** IMAP properties reported by the server. */
    public Imap.FolderProperties properties  { get; private set; }


    internal Folder(FolderPath path, Imap.FolderProperties properties) {
        this.path = path;
        this.properties = properties;
    }

    public string to_string() {
        return "Imap.Folder(%s)".printf(path.to_string());
    }

}
