/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2018 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

class GriabuntuMail.AccountInformationTest : TestCase {


    public AccountInformationTest() {
        base("GriabuntuMail.AccountInformationTest");
        add_test("test_save_sent_defaults", test_save_sent_defaults);
        add_test("test_sender_mailboxes", test_sender_mailboxes);
        add_test("test_service_label", test_service_label);
        add_test("test_account_backend_default", test_account_backend_default);
        add_test("test_account_backend_copy_and_equal", test_account_backend_copy_and_equal);
        add_test("folder_steps_accessors", folder_steps_accessors);
    }

    public void test_save_sent_defaults() throws GLib.Error {
        assert_true(
            new AccountInformation(
                "test",
                ServiceProvider.OTHER,
                new Mock.CredentialsMediator(),
                new RFC822.MailboxAddress(null, "test1@example.com")
            ).save_sent
        );
        assert_false(
            new AccountInformation(
                "test",
                ServiceProvider.GMAIL,
                new Mock.CredentialsMediator(),
                new RFC822.MailboxAddress(null, "test1@example.com")
            ).save_sent
        );
        assert_false(
            new AccountInformation(
                "test",
                ServiceProvider.OUTLOOK,
                new Mock.CredentialsMediator(),
                new RFC822.MailboxAddress(null, "test1@example.com")
            ).save_sent
        );
    }

    public void test_sender_mailboxes() throws GLib.Error {
        AccountInformation test = new AccountInformation(
            "test",
            ServiceProvider.OTHER,
            new Mock.CredentialsMediator(),
            new RFC822.MailboxAddress(null, "test1@example.com")
        );

        assert_true(test.primary_mailbox.equal_to(
                        new RFC822.MailboxAddress(null, "test1@example.com")));
        assert_false(test.has_sender_aliases);

        test.append_sender(new RFC822.MailboxAddress(null, "test2@example.com"));
        assert_true(test.has_sender_aliases);

        test.append_sender(new RFC822.MailboxAddress(null, "test3@example.com"));
        assert_true(test.has_sender_aliases);

        assert_true(
            test.has_sender_mailbox(new RFC822.MailboxAddress(null, "test1@example.com")),
            "Primary address not found"
        );
        assert_true(
            test.has_sender_mailbox(new RFC822.MailboxAddress(null, "test2@example.com")),
            "First alt address not found"
        );
        assert_true(
            test.has_sender_mailbox(new RFC822.MailboxAddress(null, "test3@example.com")),
            "Second alt address not found"
        );
        assert_false(
            test.has_sender_mailbox(new RFC822.MailboxAddress(null, "unknowne@example.com")),
            "Unknown address found"
        );
    }

    public void test_service_label() throws GLib.Error {
        AccountInformation test = new_information();
        assert_equal(test.service_label, "");

        test = new_information();
        test.incoming.host = "example.com";
        assert_equal(test.service_label, "example.com");

        test = new_information();
        test.incoming.host = "test.example.com";
        assert_equal(test.service_label, "example.com");

        test = new_information();
        test.incoming.host = "other.com";
        test.outgoing.host = "other.com";
        assert_equal(test.service_label, "other.com");

        test = new_information();
        test.incoming.host = "mail.other.com";
        test.outgoing.host = "mail.other.com";
        assert_equal(test.service_label, "other.com");

        test = new_information();
        test.incoming.host = "imap.other.com";
        test.outgoing.host = "smtp.other.com";
        assert_equal(test.service_label, "other.com");

        test = new_information();
        test.incoming.host = "not-mail.other.com";
        test.outgoing.host = "not-mail.other.com";
        assert_equal(test.service_label, "other.com");
    }

    public void folder_steps_accessors() throws GLib.Error {
        AccountInformation test = new_information();

        assert_collection(test.get_folder_steps_for_use(NONE)).is_empty();
        assert_collection(test.get_folder_steps_for_use(ARCHIVE)).is_empty();
        assert_collection(test.get_folder_steps_for_use(JUNK)).is_empty();

        var archive = new Gee.ArrayList<string>.wrap({"Archive"});
        test.set_folder_steps_for_use(ARCHIVE, archive);
        assert_collection(test.get_folder_steps_for_use(ARCHIVE))
        .is_non_empty()
        .contains("Archive");

        var junk = new Gee.ArrayList<string>.wrap({"Junk"});
        test.set_folder_steps_for_use(JUNK, junk);
        assert_collection(test.get_folder_steps_for_use(ARCHIVE))
        .is_non_empty()
        .contains("Archive");
        assert_collection(test.get_folder_steps_for_use(JUNK))
        .is_non_empty()
        .contains("Junk");
    }

    private AccountInformation new_information(ServiceProvider provider =
                                               ServiceProvider.OTHER) {
        return new AccountInformation(
            "test",
            provider,
            new Mock.CredentialsMediator(),
            new RFC822.MailboxAddress(null, "test1@example.com")
        );
    }

    public void test_account_backend_default() throws GLib.Error {
        // A freshly-constructed account should default to the IMAP_SMTP
        // backend, regardless of service provider.
        assert_true(
            new_information().account_backend == AccountBackend.IMAP_SMTP,
            "Default account_backend should be IMAP_SMTP"
        );
        assert_true(
            new_information(ServiceProvider.GMAIL).account_backend
            == AccountBackend.IMAP_SMTP,
            "GMAIL account should default to IMAP_SMTP"
        );
        assert_true(
            new_information(ServiceProvider.OUTLOOK).account_backend
            == AccountBackend.IMAP_SMTP,
            "OUTLOOK account should default to IMAP_SMTP"
        );
    }

    public void test_account_backend_copy_and_equal() throws GLib.Error {
        // A copy of an account must preserve the account_backend value
        // set on the source account.
        AccountInformation source = new_information();
        source.account_backend = AccountBackend.MICROSOFT_GRAPH;
        AccountInformation copy = new AccountInformation.copy(source);
        assert_true(
            copy.account_backend == AccountBackend.MICROSOFT_GRAPH,
            "copy() must preserve account_backend"
        );

        // Two accounts that differ only by their account_backend must
        // not be considered equal.
        AccountInformation imap = new_information();
        AccountInformation graph = new_information();
        graph.account_backend = AccountBackend.MICROSOFT_GRAPH;

        assert_false(
            imap.equal_to(graph),
            "Accounts with different backends should not be equal"
        );
        assert_false(
            graph.equal_to(imap),
            "AccountBackend equality must be symmetric"
        );

        // A copy of a graph account must also be a graph account.
        AccountInformation graph_copy = new AccountInformation.copy(graph);
        assert_true(
            graph_copy.account_backend == AccountBackend.MICROSOFT_GRAPH,
            "copy() must preserve account_backend"
        );

        // Changing only the backend on the copy should break equality.
        graph_copy.account_backend = AccountBackend.IMAP_SMTP;
        assert_false(
            graph.equal_to(graph_copy),
            "equal_to must compare account_backend"
        );
    }

}
