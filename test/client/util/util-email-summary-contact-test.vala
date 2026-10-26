/* New downstream file: 2026-10-26. LGPL-2.1-or-later; see COPYING. */
/*
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

/** Summary-contact policy only: no GTK, contacts backend, bus or mail store. */
public class Util.Email.SummaryContactTest : TestCase {

    public SummaryContactTest() {
        base("Util.Email.SummaryContactTest");
        add_test("missing_headers", missing_headers);
        add_test("first_from_not_sender_or_reply_to", first_from_not_sender_or_reply_to);
        add_test("sender_fallback", sender_fallback);
        add_test("outgoing_first_to_then_cc", outgoing_first_to_then_cc);
        add_test("summary_switch_and_literal_name", summary_switch_and_literal_name);
        add_test("negative_contact_cache_invalidated", negative_contact_cache_invalidated);
        add_test("unrelated_contact_cache_retained", unrelated_contact_cache_retained);
    }

    public void missing_headers() throws GLib.Error {
        assert_null(get_summary_contact_mailbox(null, false));
        assert_null(get_summary_contact_mailbox(null, true));
        var email = new Convey.Email(new Mock.EmailIdentifer(1));
        assert_null(get_summary_contact_mailbox(email, false));
        assert_null(get_summary_contact_mailbox(email, true));
        email.set_originators(null, null, addresses("reply@example.com"));
        email.set_receivers(null, null, addresses("hidden@example.com"));
        assert_null(get_summary_contact_mailbox(email, false));
        assert_null(get_summary_contact_mailbox(email, true));
    }

    public void first_from_not_sender_or_reply_to() throws GLib.Error {
        var email = new Convey.Email(new Mock.EmailIdentifer(1));
        email.set_originators(
            addresses("First <first@example.com>, Second <second@example.com>"),
            new Convey.RFC822.MailboxAddress(null, "sender@example.com"),
            addresses("reply@example.com")
        );
        var selected = get_summary_contact_mailbox(email, false);
        assert_non_null(selected);
        assert_equal(selected.address, "first@example.com");
    }

    public void sender_fallback() throws GLib.Error {
        var email = new Convey.Email(new Mock.EmailIdentifer(1));
        var sender = new Convey.RFC822.MailboxAddress("Sender", "sender@example.com");
        email.set_originators(null, sender, null);
        assert_true(get_summary_contact_mailbox(email, false) == sender);
        email.set_originators(new Convey.RFC822.MailboxAddresses(), sender, null);
        assert_true(get_summary_contact_mailbox(email, false) == sender);
    }

    public void outgoing_first_to_then_cc() throws GLib.Error {
        var email = new Convey.Email(new Mock.EmailIdentifer(1));
        email.set_originators(addresses("own@example.com"), null, null);
        email.set_receivers(
            addresses("first@example.com, second@example.com"),
            addresses("copy@example.com"), addresses("hidden@example.com")
        );
        var selected = get_summary_contact_mailbox(email, true);
        assert_non_null(selected);
        assert_equal(selected.address, "first@example.com");
        email.set_receivers(
            new Convey.RFC822.MailboxAddresses(),
            addresses("copy@example.com, another@example.com"), null
        );
        selected = get_summary_contact_mailbox(email, true);
        assert_non_null(selected);
        assert_equal(selected.address, "copy@example.com");
        email.set_receivers(null, null, null);
        assert_null(get_summary_contact_mailbox(email, true));
    }

    public void summary_switch_and_literal_name() throws GLib.Error {
        var first = new Convey.Email(new Mock.EmailIdentifer(1));
        var second = new Convey.Email(new Mock.EmailIdentifer(2));
        var literal = new Convey.RFC822.MailboxAddress("<b>Sender</b>", "first@example.com");
        first.set_originators(new Convey.RFC822.MailboxAddresses.single(literal), null, null);
        second.set_originators(addresses("second@example.com"), null, null);
        var selected = get_summary_contact_mailbox(first, false);
        assert_true(selected == literal);
        // Return structured data, not markup or a thread-wide cached contact.
        assert_equal(selected.name, "<b>Sender</b>");
        selected = get_summary_contact_mailbox(second, false);
        assert_non_null(selected);
        assert_equal(selected.address, "second@example.com");
    }

    public void negative_contact_cache_invalidated() throws GLib.Error {
        var cache = new Util.Cache.Lru<Folks.Individual?>(8);
        cache.set_entry("photo@example.com", null);
        assert_true(cache.has_key("photo@example.com"));
        var changed = new Gee.ArrayList<string>();
        changed.add("PHOTO@EXAMPLE.COM");
        Application.ContactStore.invalidate_address_cache(cache, changed);
        assert_false(cache.has_key("photo@example.com"));
    }

    public void unrelated_contact_cache_retained() throws GLib.Error {
        var cache = new Util.Cache.Lru<Folks.Individual?>(8);
        cache.set_entry("unchanged@example.com", null);
        var changed = new Gee.ArrayList<string>();
        changed.add("other@example.com");
        changed.add("OTHER@EXAMPLE.COM");
        Application.ContactStore.invalidate_address_cache(cache, changed);
        assert_true(cache.has_key("unchanged@example.com"));
        assert_null(cache.get_entry("unchanged@example.com"));
    }

    private Convey.RFC822.MailboxAddresses addresses(string value)
        throws GLib.Error {
        return new Convey.RFC822.MailboxAddresses.from_rfc822_string(value);
    }
}
