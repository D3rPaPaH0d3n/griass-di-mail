/* Copyright 2026 Markus Kainer <projekt@kainer.co.at>
 * SPDX-License-Identifier: GPL-3.0-only
 */
public class Application.ContactPictureTest : TestCase {
    public ContactPictureTest() {
        base("Application.ContactPictureTest");
        add_test("no_requests_without_consent", no_requests_without_consent);
        add_test("separate_company_consent", separate_company_consent);
        add_test("normalised_hash_without_plain_address", normalised_hash);
        add_test("reject_local_and_injected_domains", invalid_domains);
        add_test("free_mail_is_not_a_company", free_mail);
        add_test("fresh_settings_are_private", fresh_settings);
        add_test("reject_vector_payload", reject_vector_payload);
    }
    private void no_requests_without_consent() throws GLib.Error {
        assert_true(ContactPicture.request_urls("person@company.com", false, false).length == 0);
        assert_true(ContactPicture.request_urls("person@company.com", false, true).length == 0);
    }
    private void separate_company_consent() throws GLib.Error {
        var urls = ContactPicture.request_urls("person@company.com", true, false);
        assert_true(urls.length == 1);
        urls = ContactPicture.request_urls("person@company.com", true, true);
        assert_true(urls.length == 2);
        assert_equal(urls[1], "https://icons.duckduckgo.com/ip3/company.com.ico");
    }
    private void normalised_hash() throws GLib.Error {
        assert_equal(ContactPicture.gravatar_url(" Person@Company.com "),
                     ContactPicture.gravatar_url("person@company.com"));
        assert_false(ContactPicture.gravatar_url("person@company.com").contains("person@"));
        assert_true(ContactPicture.gravatar_url("person@company.com").has_suffix("?s=96&d=404&r=g"));
    }
    private void invalid_domains() throws GLib.Error {
        foreach (string address in new string[] { "x@localhost", "x@127.0.0.1", "x@[::1]",
            "x@foo.local", "x@foo.internal", "x@foo.test", "x@a.com/secret", "x@a.com?x=1",
            "x@a..com", "x@-a.com", "x@a-.com", "x@a.com\r\nX:1", "x@x@a.com" }) {
            assert_true(ContactPicture.request_urls(address, true, true).length == 0);
        }
    }
    private void free_mail() throws GLib.Error {
        assert_true(ContactPicture.request_urls("person@gmail.com", true, true).length == 1);
    }
    private void reject_vector_payload() throws GLib.Error {
        assert_false(ContactPicture.is_raster("<svg xmlns=\"http://www.w3.org/2000/svg\"/>".data));
        assert_false(ContactPicture.is_raster("<html>Error</html>".data));
        assert_false(ContactPicture.is_raster(new uint8[] { 0x89, 0x50 }));
        assert_true(ContactPicture.is_raster(new uint8[] { 0x89, 0x50, 0x4e, 0x47,
            0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0 }));
    }
    private void fresh_settings() throws GLib.Error {
        var settings = new GLib.Settings("io.github.d3rpapah0d3n.GriabuntuMail");
        settings.reset(Configuration.REMOTE_CONTACT_PICTURES_KEY);
        settings.reset(Configuration.COMPANY_PICTURES_KEY);
        assert_false(settings.get_boolean(Configuration.REMOTE_CONTACT_PICTURES_KEY));
        assert_false(settings.get_boolean(Configuration.COMPANY_PICTURES_KEY));
    }
}
