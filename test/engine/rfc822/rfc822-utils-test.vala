/*
 * Copyright 2016 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

class Convey.RFC822.Utils.Test : TestCase {

    public Test() {
        base("Convey.RFC822.Utils.Test");
        add_test("to_preview_text", to_preview_text);
        add_test("best_encoding_default", best_encoding_default);
        add_test("best_encoding_long_line", best_encoding_long_line);
        add_test("best_encoding_binary", best_encoding_binary);
        add_test("list_post_address", list_post_address);
        add_test("list_unsubscribe", list_unsubscribe);
    }

    public void to_preview_text() throws GLib.Error {
        assert(Convey.RFC822.Utils.to_preview_text(PLAIN_BODY_ENCODED, Convey.RFC822.TextFormat.PLAIN) ==
               PLAIN_BODY_EXPECTED);
        assert(Convey.RFC822.Utils.to_preview_text(HTML_BODY_ENCODED, Convey.RFC822.TextFormat.HTML) ==
               HTML_BODY_EXPECTED);
        assert(Convey.RFC822.Utils.to_preview_text(HTML_BODY_ENCODED, Convey.RFC822.TextFormat.HTML) ==
               HTML_BODY_EXPECTED);
    }

    public void best_encoding_default() throws GLib.Error {
        string test = "abc";
        var stream = new GMime.StreamMem.with_buffer(test.data);
        get_best_encoding.begin(stream, 7BIT, null, this.async_completion);
        var encoding = get_best_encoding.end(async_result());
        assert_true(encoding == DEFAULT);
    }

    public void best_encoding_long_line() throws GLib.Error {
        GLib.StringBuilder buf = new GLib.StringBuilder();
        for (int i = 0; i < 2000; i++) {
            buf.append("long ");
        }
        var stream = new GMime.StreamMem.with_buffer(buf.str.data);
        get_best_encoding.begin(stream, 7BIT, null, this.async_completion);
        var encoding = get_best_encoding.end(async_result());
        assert_true(encoding == QUOTEDPRINTABLE);
    }

    public void best_encoding_binary() throws GLib.Error {
        uint8 test[] = { 0x20, 0x00, 0x20 };
        var stream = new GMime.StreamMem.with_buffer(test);
        get_best_encoding.begin(stream, 7BIT, null, this.async_completion);
        var encoding = get_best_encoding.end(async_result());
        assert_true(encoding == BASE64);
    }

    public void list_post_address() throws GLib.Error {
        assert_null(get_list_post_address(email_with_header("From: a@example.com\r\n\r\n")));
        assert_null(get_list_post_address(email_with_header("List-Post: NO\r\n\r\n")));
        assert_equal(
            get_list_post_address(
                email_with_header("List-Post: <mailto:list%2Bdev@example.com?subject=hi>\r\n\r\n")
            ).to_rfc822_string(),
            "list+dev@example.com"
        );
    }

    public void list_unsubscribe() throws GLib.Error {
        var none = email_with_header("From: a@example.com\r\n\r\n");
        assert_null(get_list_unsubscribe_uri(none, { "https", "mailto" }));
        assert_false(has_one_click_unsubscribe(none));

        var both = email_with_header(
            "List-Unsubscribe: <mailto:leave@example.com?subject=unsubscribe>,\r\n" +
            " <https://example.com/u/123>\r\n" +
            "List-Unsubscribe-Post: List-Unsubscribe=One-Click\r\n\r\n"
        );
        assert_equal(
            get_list_unsubscribe_uri(both, { "https" }),
            "https://example.com/u/123"
        );
        assert_equal(
            get_list_unsubscribe_uri(both, { "mailto" }),
            "mailto:leave@example.com?subject=unsubscribe"
        );
        assert_true(has_one_click_unsubscribe(both));

        var mailto_only = email_with_header(
            "List-Unsubscribe: <mailto:leave@example.com>\r\n" +
            "List-Unsubscribe-Post: List-Unsubscribe=One-Click\r\n\r\n"
        );
        assert_null(get_list_unsubscribe_uri(mailto_only, { "https", "http" }));
        assert_false(has_one_click_unsubscribe(mailto_only));
    }

    private Email email_with_header(string header) throws GLib.Error {
        var email = new Email(new Mock.EmailIdentifer(0));
        email.set_message_header(new Header(new Memory.StringBuffer(header)));
        return email;
    }


    public static string PLAIN_BODY_ENCODED = "-----BEGIN PGP SIGNED MESSAGE-----\nHash: SHA512\n\n=============================================================================\nFreeBSD-EN-16:11.vmbus                                          Errata Notice\n                                                          The FreeBSD Project\n\nTopic:          Avoid using spin locks for channel message locks\n\nCategory:       core\nModule:         vmbus\nAnnounced:      2016-08-12\nCredits:        Microsoft OSTC\nAffects:        FreeBSD 10.3\nCorrected:      2016-06-15 09:52:01 UTC (stable/10, 10.3-STABLE)\n                2016-08-12 04:01:16 UTC (releng/10.3, 10.3-RELEASE-p7)\n\nFor general information regarding FreeBSD Errata Notices and Security\nAdvisories, including descriptions of the fields above, security\nbranches, and the following sections, please visit\n<URL:https://security.FreeBSD.org/>.\n";
    public static string PLAIN_BODY_EXPECTED = "FreeBSD-EN-16:11.vmbus Errata Notice The FreeBSD Project Topic: Avoid using spin locks for channel message locks Category: core Module: vmbus Announced: 2016-08-12 Credits: Microsoft OSTC Affects: FreeBSD 10.3 Corrected: 2016-06-15 09:52:01 UTC (stable/10, 10.3-STABLE) 2016-08-12 04:01:16 UTC (releng/10.3, 10.3-RELEASE-p7) For general information regarding FreeBSD Errata Notices and Security Advisories, including descriptions of the fields above, security branches, and the following sections, please visit <URL:https://security.FreeBSD.org/>.";

    public static string HTML_BODY_ENCODED = """<html><head>
<meta http-equiv=Content-Type content="text/html; charset=utf-8">
<style>
.bodyblack { font-family: Verdana, Arial, Helvetica, sans-serif; font-size: 12px; }
td { font-size: 12px; }
.footer { font-family: Verdana, Arial, Helvetica, sans-serif; font-size: 10px; }
</style>
</head>
<body><table cellSpacing="0" cellPadding="0" width="450" border="0" class="bodyblack"><tr><td>
<p><br />Hi Kenneth, <br /> <br /> We xxxxx xxxx xx xxx xxx xx xxxx x xxxxxxxx xxxxxxxx.
<br /> <br /> <br /> <br />Thank you, <br /> <br />XXXXX
X XXXXXX<br /><br />You can reply directly to this message or click the following link:<br /><a href="https://app.foobar.com/xxxxxxxx752a0ab01641966deff6c48623aba">https://app.foobar.com/xxxxxxxxxxxxxxxx1641966deff6c48623aba</a><br /><br />You can change your email preferences at:<br /><a href="https://app.foobar.com/xxxxxxxxxxxxx">https://app.foobar.com/xxxxxxxxxxx</a></p></td></tr>
</table></body></html>
""";

    public static string HTML_BODY_EXPECTED = "Hi Kenneth, We xxxxx xxxx xx xxx xxx xx xxxx x xxxxxxxx xxxxxxxx. Thank you, XXXXX X XXXXXX You can reply directly to this message or click the following link: https://app.foobar.com/xxxxxxxxxxxxxxxx1641966deff6c48623aba You can change your email preferences at: https://app.foobar.com/xxxxxxxxxxx";

}
