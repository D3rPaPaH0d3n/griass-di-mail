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
 * A representation of an IMAP quoted string.
 *
 * This class does not check if quoting is required.  Use {@link DataFormat.is_quoting_required}
 * or {@link StringParameter.get_best_for}.
 *
 * {@link Deserializer} will never generate this {@link Parameter}.
 *
 * See [[http://tools.ietf.org/html/rfc3501#section-4.3]].
 */
public class GriabuntuMail.Imap.QuotedStringParameter : GriabuntuMail.Imap.StringParameter {
    public QuotedStringParameter(string ascii) {
        base (ascii);
    }

    /**
     * {@inheritDoc}
     */
    public override string to_string() {
        return "\"%s\"".printf(ascii);
    }

    /**
     * {@inheritDoc}
     */
    public override void serialize(Serializer ser, GLib.Cancellable cancellable)
        throws GLib.Error {
        ser.push_quoted_string(ascii, cancellable);
    }

}
