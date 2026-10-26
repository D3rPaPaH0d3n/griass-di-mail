/* New downstream file: 2026-10-26. LGPL-2.1-or-later; see COPYING. */
/* Licensed under LGPL-2.1-or-later. See COPYING. */
public class Util.Date.ReceivedTimeTest : TestCase {
    public ReceivedTimeTest() {
        base("Util.Date.ReceivedTimeTest");
        add_test("exact_local_seconds", exact_local_seconds);
        add_test("local_midnight_rollover", local_midnight_rollover);
        add_test("repeated_dst_hour", repeated_dst_hour);
        add_test("missing_date_is_empty", missing_date_is_empty);
    }

    public void exact_local_seconds() throws GLib.Error {
        var received = new DateTime.from_iso8601("2026-10-26T15:28:42Z", null);
        assert_equal(format_received(received), "26.10.2026\n16:28:42");
        assert_true("+0100" in format_received_tooltip(received));
    }

    public void local_midnight_rollover() throws GLib.Error {
        var received = new DateTime.from_iso8601("2026-01-01T23:59:07Z", null);
        assert_equal(format_received(received), "02.01.2026\n00:59:07");
    }

    public void repeated_dst_hour() throws GLib.Error {
        var early = new DateTime.from_iso8601("2026-10-25T00:30:15Z", null);
        var late = new DateTime.from_iso8601("2026-10-25T01:30:15Z", null);
        assert_equal(format_received(early), "25.10.2026\n02:30:15");
        assert_equal(format_received(late), format_received(early));
        assert_true("+0200" in format_received_tooltip(early));
        assert_true("+0100" in format_received_tooltip(late));
    }

    public void missing_date_is_empty() throws GLib.Error {
        assert_equal(format_received(null), "");
        assert_equal(format_received_tooltip(null), "");
    }
}
