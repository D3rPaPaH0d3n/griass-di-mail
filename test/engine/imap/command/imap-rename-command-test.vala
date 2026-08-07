/*
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
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
