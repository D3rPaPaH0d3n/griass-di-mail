/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2017 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

class GriabuntuMail.Imap.CreateCommandTest : TestCase {


    public CreateCommandTest() {
        base("GriabuntuMail.Imap.CreateCommandTest");
        add_test("basic_create", basic_create);
        add_test("special_use", special_use);
    }

    public void basic_create() throws Error {
        assert_equal(
            new CreateCommand(new MailboxSpecifier("owatagusiam/"), null).to_string(),
            "---- create owatagusiam/"
        );
    }

    public void special_use() throws Error {
        assert_equal(
            new CreateCommand.special_use(
                new MailboxSpecifier("Everything"),
                ALL_MAIL,
                null
            ).to_string(),
            "---- create Everything (use (\\All))"
        );
    }

}
