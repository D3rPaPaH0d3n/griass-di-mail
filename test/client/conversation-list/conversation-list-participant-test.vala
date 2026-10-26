/* Licensed under LGPL-2.1-or-later. See COPYING. */
public class ConversationList.ParticipantDisplayTest : TestCase {
    public ParticipantDisplayTest() {
        base("ConversationList.ParticipantDisplayTest");
        add_test("name_and_address", name_and_address);
        add_test("address_without_name", address_without_name);
        add_test("own_address_not_hidden", own_address_not_hidden);
        add_test("short_threads_keep_addresses", short_threads_keep_addresses);
        add_test("literal_markup_and_spoof", literal_markup_and_spoof);
    }

    private Gee.List<Convey.RFC822.MailboxAddress> accounts() {
        return new Gee.ArrayList<Convey.RFC822.MailboxAddress>();
    }

    public void name_and_address() throws GLib.Error {
        var p = new Participant(new Convey.RFC822.MailboxAddress("Example", "sender@example.com"));
        assert_equal(p.get_full_markup(accounts()), "Example &lt;sender@example.com&gt;");
    }

    public void address_without_name() throws GLib.Error {
        var p = new Participant(new Convey.RFC822.MailboxAddress(null, "sender@example.com"));
        assert_equal(p.get_full_markup(accounts()), "sender@example.com");
    }

    public void own_address_not_hidden() throws GLib.Error {
        var mailbox = new Convey.RFC822.MailboxAddress("Own", "own@example.com");
        var own = accounts();
        own.add(mailbox);
        var p = new Participant(mailbox);
        assert_equal(p.get_full_markup(own), "Me &lt;own@example.com&gt;");
    }

    public void short_threads_keep_addresses() throws GLib.Error {
        var p = new Participant(new Convey.RFC822.MailboxAddress("Last, First", "sender@example.com"));
        assert_equal(p.get_short_markup(accounts()), p.get_full_markup(accounts()));
        assert_true("sender@example.com" in p.get_short_markup(accounts()));
    }

    public void literal_markup_and_spoof() throws GLib.Error {
        var p = new Participant(new Convey.RFC822.MailboxAddress("<b>Example</b>", "sender@example.com"));
        string markup = p.get_full_markup(accounts());
        assert_false("<b>" in markup);
        assert_true("&lt;b&gt;" in markup);
        p = new Participant(new Convey.RFC822.MailboxAddress("trusted@example.com", "other@example.org"));
        assert_true(p.address.is_spoofed());
        assert_equal(p.get_full_markup(accounts()), "<s>other@example.org</s>");
    }
}
