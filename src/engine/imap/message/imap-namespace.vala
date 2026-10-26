/*
 * Copyright 2016 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * Namespace component in a response for a NAMESPACE command.
 *
 * @see Convey.Imap.NamespaceCommand
 */
public class Convey.Imap.Namespace : BaseObject {


    public string prefix { get; private set; }
    public string? delim { get; private set; }


    public Namespace(string prefix, string? delim) {
        this.prefix = prefix;
        this.delim = delim;
    }

    public string to_string() {
        return "(%s,%s)".printf(this.prefix, this.delim ?? "NIL");
    }

}
