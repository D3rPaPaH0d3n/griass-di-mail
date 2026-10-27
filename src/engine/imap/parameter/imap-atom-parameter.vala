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
 * A representation of an IMAP atom.
 *
 * This class does not check if quoting is required.  Use {@link DataFormat.is_quoting_required}
 * or {@link StringParameter.get_best_for}.
 *
 * See {@link StringParameter} for a note about class hierarchy.  In particular, note that
 * [@link Deserializer} will not create this type of {@link Parameter} because it's unable to
 * deduce if a string is an atom or a string from syntax alone.
 *
 * See [[http://tools.ietf.org/html/rfc3501#section-4.1]]
 */
public class GriabuntuMail.Imap.AtomParameter : GriabuntuMail.Imap.UnquotedStringParameter {

    public AtomParameter(string value) {
        base (value);
    }

    /**
     * {@inheritDoc}
     */
    public override void serialize(Serializer ser, GLib.Cancellable cancellable)
        throws GLib.Error {
        ser.push_unquoted_string(ascii);
    }

}
