/* New downstream file: 2026-10-28. GPL-3.0-only; see COPYING. */
public class Application.NotificationJournalTest : TestCase {
    private GLib.File? directory;

    public NotificationJournalTest() {
        base("Application.NotificationJournalTest");
        add_test("crash_recovery_and_private_file", crash_recovery_and_private_file);
        add_test("retired_ids_and_clean_shutdown", retired_ids_and_clean_shutdown);
        add_test("foreign_ids_are_never_recovered", foreign_ids_are_never_recovered);
        add_test("failed_record_does_not_claim_persistence", failed_record_does_not_claim_persistence);
        add_test("retired_and_cancelled_async_delivery", retired_and_cancelled_async_delivery);
    }

    public override void set_up() throws GLib.Error {
        this.directory = GLib.File.new_for_path(GLib.DirUtils.make_tmp("popup-journal-XXXXXX"));
    }

    public override void tear_down() throws GLib.Error {
        if (this.directory != null) delete_file(this.directory);
        this.directory = null;
    }

    public void crash_recovery_and_private_file() throws GLib.Error {
        var file = this.directory.get_child("private").get_child("popups.ini");
        var journal = new NotificationJournal(file);
        journal.record("email-arrived-synthetic-one");
        journal.record("email-arrived-synthetic-two");
        journal.record("email-arrived-synthetic-one");
        // Reconstruct with no clean shutdown, as after a killed process.
        var recovered = new NotificationJournal(file);
        assert_true(recovered.get_ids().size == 2);
        assert_true(recovered.get_ids().contains("email-arrived-synthetic-one"));
        var info = file.query_info(GLib.FileAttribute.UNIX_MODE, NONE);
        assert_true((info.get_attribute_uint32(GLib.FileAttribute.UNIX_MODE) & 0777) == 0600);
        info = file.get_parent().query_info(GLib.FileAttribute.UNIX_MODE, NONE);
        assert_true((info.get_attribute_uint32(GLib.FileAttribute.UNIX_MODE) & 0777) == 0700);
        uint8[] data;
        file.load_contents(null, out data, null);
        var values = new GLib.KeyFile();
        values.load_from_data((string) data, data.length, NONE);
        assert_true(values.get_groups().length == 1);
        assert_true(values.get_keys("Mail").length == 1);
    }

    public void retired_ids_and_clean_shutdown() throws GLib.Error {
        var file = this.directory.get_child("popups.ini");
        var journal = new NotificationJournal(file);
        journal.record("email-arrived-synthetic-one");
        journal.record("email-arrived-synthetic-two");
        journal.forget("email-arrived-synthetic-one");
        assert_false(new NotificationJournal(file).get_ids().contains("email-arrived-synthetic-one"));
        assert_true(new NotificationJournal(file).get_ids().contains("email-arrived-synthetic-two"));
        journal.clear();
        assert_true(new NotificationJournal(file).get_ids().is_empty);
    }

    public void foreign_ids_are_never_recovered() throws GLib.Error {
        var file = this.directory.get_child("popups.ini");
        var values = new GLib.KeyFile();
        values.set_string_list("Mail", "ids", {
            "error", "other-app-notification", "email-arrived-", "email-arrived-fake\nerror",
            "email-arrived-synthetic-owned"
        });
        GLib.FileUtils.set_contents(file.get_path(), values.to_data());
        var journal = new NotificationJournal(file);
        assert_true(journal.get_ids().size == 1);
        assert_true(journal.get_ids().contains("email-arrived-synthetic-owned"));
        GLib.Error? rejected = null;
        try {
            journal.record("error");
        } catch (GLib.Error error) {
            rejected = error;
        }
        assert_error(rejected, new GLib.IOError.INVALID_ARGUMENT(""));
    }

    public void failed_record_does_not_claim_persistence() throws GLib.Error {
        var file = this.directory.get_child("popups.ini");
        var journal = new NotificationJournal(file);
        file.make_directory(); // Force atomic replacement to fail.
        GLib.Error? rejected = null;
        try {
            journal.record("email-arrived-synthetic-one");
        } catch (GLib.Error error) {
            rejected = error;
        }
        assert_non_null(rejected);
        assert_true(journal.get_ids().is_empty);
    }

    public void retired_and_cancelled_async_delivery() throws GLib.Error {
        var guard = new NotificationDeliveryGuard();
        var request = new GLib.Cancellable();
        int64 one = guard.capture("account-one/inbox");
        int64 two = guard.capture("account-two/inbox");
        assert_true(guard.is_current("account-one/inbox", one, request));
        guard.invalidate("account-one/inbox");
        assert_false(guard.is_current("account-one/inbox", one, request));
        assert_true(guard.is_current("account-two/inbox", two, request));
        int64 next = guard.capture("account-one/inbox");
        assert_true(guard.is_current("account-one/inbox", next, request));
        request.cancel();
        assert_false(guard.is_current("account-one/inbox", next, request));
        assert_false(guard.is_current("account-two/inbox", two, request));
        // A later session's work is valid without reviving the old request.
        assert_true(guard.is_current("account-one/inbox", next, new GLib.Cancellable()));
        assert_false(guard.is_current("account-one/inbox", next, request));
    }
}
