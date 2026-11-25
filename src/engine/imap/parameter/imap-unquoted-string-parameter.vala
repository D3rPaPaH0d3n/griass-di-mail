/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * A representation of an IMAP string that is not quoted.
 *
 * This class does not check if quoting is required.  Use {@link DataFormat.is_quoting_required}
 * or {@link StringParameter.get_best_for}.
 *
 * The difference between this class and {@link AtomParameter} is that this can be used in any
 * circumstance where a string can (or is) represented without quotes or literal data, whereas an
 * atom has strict definitions about where it's found.
 *
 * See [[http://tools.ietf.org/html/rfc3501#section-4.1]]
 */
public class GriabuntuMail.Imap.UnquotedStringParameter : GriabuntuMail.Imap.StringParameter {

    public UnquotedStringParameter(string ascii) {
        base (ascii);
    }

    /**
     * {@inheritDoc}
     */
    public override void serialize(Serializer ser, GLib.Cancellable cancellable)
        throws GLib.Error {
        ser.push_unquoted_string(ascii, cancellable);
    }

    /**
     * {@inheritDoc}
     */
    public override string to_string() {
        return ascii;
    }

}
