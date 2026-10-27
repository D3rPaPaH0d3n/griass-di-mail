/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

public class GriabuntuMail.Imap.EmailProperties : GriabuntuMail.EmailProperties, Gee.Hashable<GriabuntuMail.Imap.EmailProperties> {


    public InternalDate? internaldate { get; private set; }
    public RFC822Size? rfc822_size { get; private set; }

    public EmailProperties(InternalDate internaldate,
                           RFC822Size rfc822_size) {
        base (internaldate.value, rfc822_size.value);
        this.internaldate = internaldate;
        this.rfc822_size = rfc822_size;
    }

    public bool equal_to(GriabuntuMail.Imap.EmailProperties other) {
        if (this == other)
            return true;

        // for simplicity and robustness, internaldate and rfc822_size must be present in both
        // to be considered equal
        if (internaldate == null || other.internaldate == null)
            return false;

        if (rfc822_size == null || other.rfc822_size == null)
            return false;

        return true;
    }

    public uint hash() {
        return to_string().hash();
    }

    public override string to_string() {
        return "internaldate:%s/size:%s".printf((internaldate != null) ? internaldate.to_string() : "(none)",
            (rfc822_size != null) ? rfc822_size.to_string() : "(none)");
    }
}

