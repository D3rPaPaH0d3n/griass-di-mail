/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * The base respresentation of an complete IMAP message.
 *
 * By definition, a top-level {@link ListParameter}.  A RootParameters object should never be
 * added to another list.
 *
 * @see ServerResponse
 * @see Command
 */

public class Convey.Imap.RootParameters : Convey.Imap.ListParameter {
    public RootParameters() {
    }

    /**
     * Moves all contained {@link Parameter} objects inside the supplied RootParameters into a
     * new RootParameters.
     *
     * The supplied root object is stripped clean by this call.
     */
    public RootParameters.migrate(RootParameters root) {
        adopt_children(root);
    }

    /**
     * Returns null if the first parameter is not a StringParameter that resembles a Tag.
     */
    public Tag? get_tag() {
        StringParameter? strparam = get_if_string(0);
        if (strparam == null)
            return null;

        if (!Tag.is_tag(strparam))
            return null;

        return new Tag.from_parameter(strparam);
    }

    /**
     * Returns true if the first parameter is a StringParameter that resembles a Tag.
     */
    public bool has_tag() {
        StringParameter? strparam = get_if_string(0);
        if (strparam == null)
            return false;

        return (strparam != null) ? Tag.is_tag(strparam) : false;
    }

    /**
     * {@inheritDoc}
     */
    public override string to_string() {
        return stringize_list();
    }

    /**
     * {@inheritDoc}
     */
    public override void serialize(Serializer ser, GLib.Cancellable cancellable)
        throws GLib.Error {
        serialize_list(ser, cancellable);
        ser.push_eol(cancellable);
    }

}
