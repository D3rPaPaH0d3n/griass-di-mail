/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

namespace GriabuntuMail.RFC822 {

    /**
     * Common text formats supported by {@link GriabuntuMail.RFC822}.
     */
    public enum TextFormat {
        PLAIN,
        HTML
    }

    /**
     * Official IANA charset encoding name for the UTF-8 character set.
     */
    public const string UTF8_CHARSET = "UTF-8";

    /**
     * Official IANA charset encoding name for the ASCII  character set.
     */
    public const string ASCII_CHARSET = "US-ASCII";

    internal GMime.ParserOptions gmime_parser_options;

    internal Regex? invalid_filename_character_re;

    private int init_count = 0;


    public void init() {
        if (init_count++ != 0)
            return;

        GMime.init();

        gmime_parser_options = GMime.ParserOptions.get_default();
        gmime_parser_options.set_allow_addresses_without_domain(true);
        gmime_parser_options.set_address_compliance_mode(LOOSE);
        gmime_parser_options.set_parameter_compliance_mode(LOOSE);
        gmime_parser_options.set_rfc2047_compliance_mode(LOOSE);

        try {
            invalid_filename_character_re = new Regex("[/\\0]");
        } catch (RegexError e) {
            assert_not_reached();
        }
    }

    public GMime.FormatOptions get_format_options() {
        return GMime.FormatOptions.get_default();
    }

    public GMime.ParserOptions get_parser_options() {
        return GriabuntuMail.RFC822.gmime_parser_options;
    }

    public string? get_charset() {
        return UTF8_CHARSET;
    }

    internal bool is_utf_8(string charset) {
        string up = charset.up();
        return (
            // ASCII is a subset of UTF-8, so it's also valid
            up == "ASCII" ||
            up == "US-ASCII" ||
            up == "US_ASCII" ||
            up == "UTF-8" ||
            up == "UTF8" ||
            up == "UTF_8"
        );
    }

}
