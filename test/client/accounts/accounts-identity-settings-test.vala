/* New downstream file: 2026-10-28. GPL-3.0-only; see COPYING. */
public class Accounts.IdentitySettingsTest : TestCase {
    private GriabuntuMail.AccountInformation account;
    private GriabuntuMail.RFC822.MailboxAddress alias;

    public IdentitySettingsTest() {
        base("Accounts.IdentitySettingsTest");
        add_test("colors_copy_reset_and_validation", colors_copy_reset_and_validation);
        add_test("identities_and_colors_survive_restart", identities_and_colors_survive_restart);
        add_test("legacy_config_and_invalid_colors", legacy_config_and_invalid_colors);
        add_test("legacy_aliases_survive_version_upgrade", legacy_aliases_survive_version_upgrade);
        add_test("reorder_preserves_color_ownership", reorder_preserves_color_ownership);
    }

    public override void set_up() {
        this.account = new GriabuntuMail.AccountInformation(
            "synthetic", OTHER, new Mock.CredentialsMediator(),
            new GriabuntuMail.RFC822.MailboxAddress("Primary", "primary@example.test")
        );
        this.alias = new GriabuntuMail.RFC822.MailboxAddress("Alias", "alias@example.test");
        this.account.append_sender(this.alias);
    }

    public void colors_copy_reset_and_validation() throws GLib.Error {
        assert_equal(this.account.color, "");
        assert_equal(this.account.get_sender_color(this.alias), "");
        this.account.color = "#AABBCC";
        this.account.set_sender_color(this.alias, "#1234AB");
        var copy = new GriabuntuMail.AccountInformation.copy(this.account);
        // The inherited copy constructor allocates a fresh account ordinal.
        copy.ordinal = this.account.ordinal;
        assert_true(copy.equal_to(this.account));
        assert_equal(copy.color, "#aabbcc");
        var uppercase = new GriabuntuMail.RFC822.MailboxAddress(null, "ALIAS@EXAMPLE.TEST");
        assert_equal(copy.get_sender_color(uppercase), "#1234ab");
        copy.set_sender_color(uppercase, "");
        assert_equal(copy.get_sender_color(this.alias), "");
        assert_false(copy.equal_to(this.account));
        assert_equal(this.account.get_sender_color(this.alias), "#1234ab");
        foreach (string invalid in new string[] { "red", "#abc", "#12345678", "#12gg56", "#123456; color:red" }) {
            copy.color = invalid;
            copy.set_sender_color(this.alias, invalid);
            assert_equal(copy.color, "");
            assert_equal(copy.get_sender_color(this.alias), "");
        }
    }

    public void identities_and_colors_survive_restart() throws GLib.Error {
        this.account.color = "#215d58";
        this.account.set_sender_color(this.alias, "#cf7830");
        this.account.set_sender_signature(this.alias, "Alias signature");
        var dir = GLib.File.new_for_path(GLib.DirUtils.make_tmp("identity-config-XXXXXX"));
        var file = new GriabuntuMail.ConfigFile(dir.get_child("config.ini"));
        var config = new Accounts.AccountConfigV1(false);
        config.save(this.account, file);
        file.save.begin(null, this.async_completion);
        file.save.end(async_result());
        var disk = new GriabuntuMail.ConfigFile(dir.get_child("config.ini"));
        disk.load.begin(null, this.async_completion);
        disk.load.end(async_result());
        var copy = config.load(disk, this.account.id, this.account.mediator, null, null);
        assert_true(this.account.equal_to(copy));
        assert_true(copy.has_sender_aliases);
        assert_true(copy.has_sender_mailbox(this.alias));
        assert_equal(copy.get_sender_color(this.alias), "#cf7830");
        dir.get_child("config.ini").delete();
        dir.delete();
    }

    public void legacy_config_and_invalid_colors() throws GLib.Error {
        var file = new GriabuntuMail.ConfigFile(GLib.File.new_for_path("/tmp/not-written.ini"));
        var config = new Accounts.AccountConfigV1(false);
        config.save(this.account, file);
        var group = file.get_group("Account");
        group.set_string("color", "invalid");
        var colors = new Gee.ArrayList<string>();
        colors.add("#bad");
        colors.add("#123456");
        group.set_string_list("sender_colors", colors);
        var copy = config.load(file, this.account.id, this.account.mediator, null, null);
        assert_equal(copy.color, "");
        assert_equal(copy.get_sender_color(copy.primary_mailbox), "");
        assert_equal(copy.get_sender_color(this.alias), "#123456");
        // Empty/missing optional values must remain compatible with old accounts.
        group.set_string_list("sender_colors", new Gee.ArrayList<string>());
        copy = config.load(file, this.account.id, this.account.mediator, null, null);
        assert_equal(copy.get_sender_color(this.alias), "");
    }

    public void reorder_preserves_color_ownership() throws GLib.Error {
        var primary = this.account.primary_mailbox;
        this.account.set_sender_color(this.alias, "#ff0000");
        this.account.set_sender_color(primary, "#0000ff");
        this.account.remove_sender(this.alias);
        this.account.insert_sender(0, this.alias);
        var file = new GriabuntuMail.ConfigFile(GLib.File.new_for_path("/tmp/not-written.ini"));
        var config = new Accounts.AccountConfigV1(false);
        config.save(this.account, file);
        var copy = config.load(file, this.account.id, this.account.mediator, null, null);
        assert_true(copy.primary_mailbox.equal_to(this.alias));
        assert_equal(copy.get_sender_color(this.alias), "#ff0000");
        assert_equal(copy.get_sender_color(primary), "#0000ff");
    }

    public void legacy_aliases_survive_version_upgrade() throws GLib.Error {
        var dir = GLib.File.new_for_path(GLib.DirUtils.make_tmp("legacy-identities-XXXXXX"));
        var legacy_file = new GriabuntuMail.ConfigFile(dir.get_child("legacy.ini"));
        var group = legacy_file.get_group(Accounts.AccountConfigLegacy.GROUP);
        group.set_string("primary_email", "primary@example.test");
        group.set_string("real_name", "Primary");
        group.set_string("nickname", "Legacy account");
        var aliases = new Gee.ArrayList<string>();
        // Old files can contain comma-separated mailboxes within each list item.
        aliases.add("\"Alias, One\" <alias@example.test>, Second <second@example.test>");
        aliases.add("PRIMARY@EXAMPLE.TEST");
        group.set_string_list("alternate_emails", aliases);

        var legacy = new Accounts.AccountConfigLegacy();
        var imported = legacy.load(
            legacy_file, "synthetic-legacy", this.account.mediator, OTHER, null
        );
        assert_equal<int?>(imported.sender_mailboxes.size, 3);
        assert_equal(imported.primary_mailbox.address, "primary@example.test");
        assert_equal(imported.sender_mailboxes[1].name, "Alias, One");
        assert_equal(imported.sender_mailboxes[2].address, "second@example.test");

        // Manager upgrades legacy accounts by saving V1, then loads that on restart.
        var config = new Accounts.AccountConfigV1(false);
        var upgraded_file = new GriabuntuMail.ConfigFile(dir.get_child("config.ini"));
        config.save(imported, upgraded_file);
        upgraded_file.save.begin(null, this.async_completion);
        upgraded_file.save.end(async_result());
        var disk = new GriabuntuMail.ConfigFile(dir.get_child("config.ini"));
        disk.load.begin(null, this.async_completion);
        disk.load.end(async_result());
        var restarted = config.load(
            disk, imported.id, this.account.mediator, null, null
        );
        assert_true(imported.equal_to(restarted));
        assert_equal<int?>(restarted.sender_mailboxes.size, 3);
        assert_equal(restarted.primary_mailbox.address, "primary@example.test");
        assert_equal(restarted.sender_mailboxes[1].address, "alias@example.test");
        assert_equal(restarted.sender_mailboxes[2].address, "second@example.test");
        dir.get_child("config.ini").delete();
        dir.delete();
    }
}
