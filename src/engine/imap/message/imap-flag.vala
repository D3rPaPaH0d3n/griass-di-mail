/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * A generic IMAP message or mailbox flag.
 *
 * In IMAP, message and mailbox flags have similar syntax, which is encapsulated here.
 *
 * @see MessageFlag
 * @see MailboxAttribute
 */

public abstract class GriabuntuMail.Imap.Flag : BaseObject, Gee.Hashable<GriabuntuMail.Imap.Flag> {
    public string value { get; private set; }

    /**
     * Constructs a new flag.
     *
     * The given keyword must be an IMAP atom.
     */
    protected Flag(string name) {
        this.value = name;
    }

    public bool is_system() {
        return value[0] == '\\';
    }

    public bool equals_string(string value) {
        return Ascii.stri_equal(this.value, value);
    }

    public bool equal_to(GriabuntuMail.Imap.Flag flag) {
        return (flag == this) ? true : flag.equals_string(value);
    }

    /**
     * Returns the {@link Flag} as an appropriate {@link Parameter}.
     */
    public StringParameter to_parameter() throws ImapError {
        return new UnquotedStringParameter(value);
    }

    public uint hash() {
        return Ascii.stri_hash(value);
    }

    public string to_string() {
        return value;
    }
}



