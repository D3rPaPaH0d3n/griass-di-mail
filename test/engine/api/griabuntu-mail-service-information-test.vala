/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2018 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

class GriabuntuMail.TlsNegotiationMethodTest : TestCase {


    public TlsNegotiationMethodTest() {
        base("GriabuntuMail.TlsNegotiationMethodTest");
        add_test("to_value", to_value);
        add_test("for_value", for_value);
    }

    public void to_value() throws GLib.Error {
        assert_equal(TlsNegotiationMethod.START_TLS.to_value(), "start-tls");
    }

    public void for_value() throws GLib.Error {
        assert_equal(
            TlsNegotiationMethod.for_value("start-tls").to_string(),
            TlsNegotiationMethod.START_TLS.to_string(),
            "start-tls"
        );
        assert_equal(
            TlsNegotiationMethod.for_value("Start-TLS").to_string(),
            TlsNegotiationMethod.START_TLS.to_string(),
            "Start-TLS"
        );
    }

}