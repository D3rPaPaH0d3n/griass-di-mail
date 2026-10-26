/*
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

class Convey.Imap.RenameCommandTest : TestCase {


    public RenameCommandTest() {
        base("Convey.Imap.RenameCommandTest");
        add_test("basic_rename", basic_rename);
    }

    public void basic_rename() throws Error {
        assert_equal(
            new RenameCommand(
                new MailboxSpecifier("owatagusiam/"),
                new MailboxSpecifier("blurdybloop/"),
                null
            ).to_string(),
            "---- RENAME owatagusiam/ blurdybloop/"
        );
    }

}
