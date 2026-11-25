/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2019 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

public class GriabuntuMail.Outbox.EmailIdentifierTest : TestCase {


    public EmailIdentifierTest() {
        base("GriabuntuMail.Outbox.EmailIdentifierTest");
        add_test("variant_representation", variant_representation);
    }

    public void variant_representation() throws GLib.Error {
        EmailIdentifier orig = new EmailIdentifier(123, 321);
        GLib.Variant variant = orig.to_variant();
        EmailIdentifier copy = new EmailIdentifier.from_variant(variant);

        assert_true(orig.equal_to(copy));
    }

}
