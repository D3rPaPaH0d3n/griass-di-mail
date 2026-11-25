/* New downstream file: 2026-10-28. GPL-3.0-only; see COPYING. */
public class Accounts.SenderDiscoveryTest : TestCase {
    public SenderDiscoveryTest() {
        base("Accounts.SenderDiscoveryTest");
        add_test("only_verified_identities", only_verified_identities);
        add_test("rejects_malformed_addresses", rejects_malformed_addresses);
        add_test("preserves_local_identity_settings", preserves_local_identity_settings);
        add_test("distinguishes_disabled_api", distinguishes_disabled_api);
        add_test("rejects_invalid_response_shape", rejects_invalid_response_shape);
    }

    public void only_verified_identities() throws GLib.Error {
        var identities = SenderDiscovery.parse_gmail("""
            {"sendAs":[
                {"sendAsEmail":"primary@example.test","isPrimary":true},
                {"sendAsEmail":"alias@example.test","displayName":"Alias","verificationStatus":"accepted"},
                {"sendAsEmail":"ALIAS@EXAMPLE.TEST","verificationStatus":"accepted"},
                {"sendAsEmail":"pending@example.test","verificationStatus":"pending"},
                {"sendAsEmail":"missing@example.test"},
                {"sendAsEmail":"fake@example.test","isPrimary":"true"},
                {"sendAsEmail":"wrong@example.test","verificationStatus":true},
                null, 42
            ]}
        """);
        assert_equal<int?>(identities.size, 2);
        assert_equal(identities[0].address, "primary@example.test");
        assert_equal(identities[1].address, "alias@example.test");
        assert_equal(identities[1].name, "Alias");
    }

    public void rejects_malformed_addresses() throws GLib.Error {
        var identities = SenderDiscovery.parse_gmail("""
            {"sendAs":[
                {"sendAsEmail":"Bad <bad@example.test>","verificationStatus":"accepted"},
                {"sendAsEmail":"one@example.test,two@example.test","verificationStatus":"accepted"},
                {"sendAsEmail":"bad@example.test\r\nBcc: other@example.test","verificationStatus":"accepted"},
                {"sendAsEmail":" leading@example.test","verificationStatus":"accepted"},
                {"sendAsEmail":"not an email","verificationStatus":"accepted"},
                {"sendAsEmail":false,"verificationStatus":"accepted"},
                {"sendAsEmail":"valid@example.test","displayName":"A\r\nB","verificationStatus":"accepted"}
            ]}
        """);
        assert_equal<int?>(identities.size, 1);
        assert_equal(identities[0].address, "valid@example.test");
        assert_equal(identities[0].name, "A  B");
    }

    public void preserves_local_identity_settings() throws GLib.Error {
        var account = new GriabuntuMail.AccountInformation(
            "synthetic", GMAIL, new Mock.CredentialsMediator(),
            new GriabuntuMail.RFC822.MailboxAddress("Local default", "local@example.test")
        );
        account.color = "#abcdef";
        account.set_sender_color(account.primary_mailbox, "#123456");
        account.set_sender_signature(account.primary_mailbox, "Local signature");
        var original = new GriabuntuMail.AccountInformation.copy(account);
        var identities = SenderDiscovery.parse_gmail("""
            {"sendAs":[
                {"sendAsEmail":"LOCAL@EXAMPLE.TEST","displayName":"Provider name","verificationStatus":"accepted"},
                {"sendAsEmail":"provider@example.test","isPrimary":true,"isDefault":true},
                {"sendAsEmail":"new@example.test","verificationStatus":"accepted"}
            ]}
        """);
        assert_true(SenderDiscovery.merge(account, identities));
        assert_false(SenderDiscovery.merge(account, identities));
        assert_equal<int?>(account.sender_mailboxes.size, 3);
        assert_equal(account.primary_mailbox.address, "local@example.test");
        assert_equal(account.primary_mailbox.name, "Local default");
        assert_equal(account.color, original.color);
        assert_equal(account.get_sender_color(account.primary_mailbox), "#123456");
        assert_equal(account.get_sender_signature(account.primary_mailbox), "Local signature");
        // Missing provider entries do not delete local or previously imported identities.
        assert_false(SenderDiscovery.merge(account, SenderDiscovery.parse_gmail("{\"sendAs\":[]}")));
        assert_equal<int?>(account.sender_mailboxes.size, 3);
        // The same settings format persists automatically discovered identities.
        var config = new AccountConfigV1(false);
        var file = new GriabuntuMail.ConfigFile(GLib.File.new_for_path("/tmp/unused-synthetic-identities.ini"));
        config.save(account, file);
        var restored = config.load(file, account.id, account.mediator, null, null);
        assert_true(account.equal_to(restored));
    }

    public void distinguishes_disabled_api() throws GLib.Error {
        assert_true(SenderDiscovery.is_api_disabled("""
            {"error":{"code":403,"errors":[{"reason":"accessNotConfigured"}]}}
        """));
        assert_true(SenderDiscovery.is_api_disabled("""
            {"error":{"details":[{"reason":"SERVICE_DISABLED"}]}}
        """));
        assert_false(SenderDiscovery.is_api_disabled("""
            {"error":{"errors":[{"reason":"insufficientPermissions"}]}}
        """));
        assert_false(SenderDiscovery.is_api_disabled("""
            {"error":{"errors":[{"reason":true}],"details":false}}
        """));
        assert_false(SenderDiscovery.is_api_disabled("not json"));
        assert_false(SenderDiscovery.is_api_disabled("[]"));
    }

    public void rejects_invalid_response_shape() throws GLib.Error {
        foreach (string invalid in new string[] { "null", "[]", "{}", "{\"sendAs\":true}" }) {
            bool rejected = false;
            try { SenderDiscovery.parse_gmail(invalid); }
            catch (SenderDiscoveryError.INVALID_RESPONSE err) { rejected = true; }
            assert_true(rejected);
        }
    }
}
