/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2017 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

public class Mock.EmailIdentifer : GriabuntuMail.EmailIdentifier {


    private int id;


    public EmailIdentifer(int id) {
        this.id = id;
    }

    public override uint hash() {
        return GLib.int_hash(this.id);
    }

    public override bool equal_to(GriabuntuMail.EmailIdentifier other) {
        return (
            this.get_type() == other.get_type() &&
            this.id == ((EmailIdentifer) other).id
        );
    }


    public override string to_string() {
        return "%s(%d)".printf(
            this.get_type().name(),
            this.id
        );
    }

    public override GLib.Variant to_variant() {
        return new GLib.Variant.int32(id);
    }

    public override int natural_sort_comparator(GriabuntuMail.EmailIdentifier other) {
        EmailIdentifer? other_mock = other as EmailIdentifer;
        return (other_mock == null) ? 1 : this.id - other_mock.id;
    }

}
