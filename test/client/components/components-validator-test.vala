/*
 * Copyright 2019 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */


public class Components.ValidatorTest : TestCase {


    private Gtk.Entry? entry = null;


    public ValidatorTest() {
        base("Components.ValidatorTest");
        add_test("manual_empty", manual_empty);
        add_test("manual_valid", manual_valid);
        add_test("manual_not_required", manual_not_required);
    }

    public override void set_up() {
        this.entry = new Gtk.Entry();
    }

    public override void tear_down() {
        this.entry = null;
    }

    public void manual_empty() throws GLib.Error {
        Validator test_article = new Validator(this.entry);

        bool finished = false;
        Validator.Trigger?  reason = null;
        Validator.Validity? prev_state = null;
        test_article.state_changed.connect((r, p) => {
                finished = true;
                reason = r;
                prev_state = p;
            });

        test_article.validate();

        while (!finished) {
            this.main_loop.iteration(true);
        }

        assert_false(test_article.is_valid);
        assert_true(test_article.state == EMPTY);
        assert_true(reason == MANUAL);
        assert_true(prev_state == INDETERMINATE);
    }

    public void manual_valid() throws GLib.Error {
        this.entry.text = "OHHAI";
        Validator test_article = new Validator(this.entry);

        bool finished = false;
        Validator.Trigger?  reason = null;
        Validator.Validity? prev_state = null;
        test_article.state_changed.connect((r, p) => {
                finished = true;
                reason = r;
                prev_state = p;
            });

        test_article.validate();

        while (!finished) {
            this.main_loop.iteration(true);
        }

        assert_true(test_article.is_valid);
        assert_true(test_article.state == VALID);
        assert_true(reason == MANUAL);
        assert_true(prev_state == INDETERMINATE);
    }

    public void manual_not_required() throws GLib.Error {
        Validator test_article = new Validator(this.entry);
        test_article.is_required = false;

        bool finished = false;
        Validator.Trigger?  reason = null;
        Validator.Validity? prev_state = null;
        test_article.state_changed.connect((r, p) => {
                finished = true;
                reason = r;
                prev_state = p;
            });

        test_article.validate();

        while (!finished) {
            this.main_loop.iteration(true);
        }

        assert_true(test_article.is_valid);
        assert_true(test_article.state == VALID);
        assert_true(reason == MANUAL);
        assert_true(prev_state == INDETERMINATE);
    }

}
