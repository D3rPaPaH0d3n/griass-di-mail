/*
 * Copyright 2018 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

class Convey.String.Test : TestCase {

    public Test() {
        base("Convey.String.Test");
        add_test("test_whitespace", test_whitespace);
        add_test("test_nonprinting", test_nonprinting);
        add_test("test_contains_any_char", test_contains_any_char);
    }

    public void test_whitespace() throws Error {
        assert(reduce_whitespace("") == "");
        assert(reduce_whitespace(" ") == "");
        assert(reduce_whitespace(" ") == "");
        assert(reduce_whitespace("  ") == "");
        assert(reduce_whitespace("test") == "test");
        assert(reduce_whitespace("test ") == "test");
        assert(reduce_whitespace("test  ") == "test");
        assert(reduce_whitespace("test\n") == "test");
        assert(reduce_whitespace("test\r") == "test");
        assert(reduce_whitespace("test\t") == "test");
        assert(reduce_whitespace(" test") == "test");
        assert(reduce_whitespace("  test") == "test");
        assert(reduce_whitespace("test test") == "test test");
        assert(reduce_whitespace("test  test") == "test test");
        assert(reduce_whitespace("test\ntest") == "test test");
        assert(reduce_whitespace("test\n test") == "test test");
        assert(reduce_whitespace("test \ntest") == "test test");
        assert(reduce_whitespace("test \n test") == "test test");
        assert(reduce_whitespace("test\rtest") == "test test");
        assert(reduce_whitespace("test\ttest") == "test test");
   }

    public void test_nonprinting() throws Error {
        assert(reduce_whitespace("\0") == ""); // NUL
        assert(reduce_whitespace("\u00A0") == ""); // ENQUIRY
        assert(reduce_whitespace("\u00A0") == ""); // NO-BREAK SPACE
        assert(reduce_whitespace("\u2003") == ""); // EM SPACE
        assert(reduce_whitespace("test\n") == "test");
        assert(reduce_whitespace("test\ntest") == "test test");
    }

    public void test_contains_any_char() throws GLib.Error {
         assert(!contains_any_char("test", new unichar[]{ '@' }));
         assert(contains_any_char("@test", new unichar[]{ '@' }));
         assert(contains_any_char("te@st", new unichar[]{ '@' }));
         assert(contains_any_char("test@", new unichar[]{ '@' }));
    }

}
