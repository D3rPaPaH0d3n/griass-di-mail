/* Downstream modification: 2026-10-26 — synthetic recipient-alias, contact and markup cases. */
/*
 * Copyright 2019 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

public class Util.Email.Test : TestCase {


    private Application.Configuration? config = null;
    private Convey.AccountInformation? account = null;


    public Test() {
        base("Util.Email.Test");
        add_test("null_originator", null_originator);
        add_test("from_originator", from_originator);
        add_test("sender_originator", sender_originator);
        add_test("reply_to_originator", reply_to_originator);
        add_test("reply_to_via_originator", reply_to_via_originator);
        add_test("plain_via_originator", plain_via_originator);
        add_test("empty_search_query", empty_search_query);
        add_test("plain_search_terms", plain_search_terms);
        add_test("continuation_search_terms", continuation_search_terms);
        add_test("i18n_search_terms", i18n_search_terms);
        add_test("multiple_search_terms", multiple_search_terms);
        add_test("quoted_search_terms", quoted_search_terms);
        add_test("text_op_terms", text_op_terms);
        add_test("text_op_single_me_terms", text_op_single_me_terms);
        add_test("text_op_multiple_me_terms", text_op_multiple_me_terms);
        add_test("boolean_op_terms", boolean_op_terms);
        add_test("invalid_op_terms", invalid_op_terms);
    }

    public override void set_up() {
        this.config = new Application.Configuration(Application.Client.SCHEMA_ID);
        this.account = new Convey.AccountInformation(
            "test",
            OTHER,
            new Mock.CredentialsMediator(),
            new Convey.RFC822.MailboxAddress("test", "test@example.com")
        );
    }

    public override void tear_down() {
        this.config = null;
        this.account = null;
    }

    public void null_originator() throws GLib.Error {
        Convey.RFC822.MailboxAddress? originator = get_primary_originator(
            new_email(null, null, null)
        );

        assert_null(originator);
    }

    public void from_originator() throws GLib.Error {
        Convey.RFC822.MailboxAddress? originator = get_primary_originator(
            new_email(
                new Convey.RFC822.MailboxAddress("from", "from@example.com"),
                new Convey.RFC822.MailboxAddress("sender", "sender@example.com"),
                new Convey.RFC822.MailboxAddress("reply-to", "reply-to@example.com")
            )
        );

        assert_non_null(originator);
        assert_equal(originator.name, "from");
        assert_equal(originator.address, "from@example.com");
    }

    public void sender_originator() throws GLib.Error {
        Convey.RFC822.MailboxAddress? originator = get_primary_originator(
            new_email(
                null,
                new Convey.RFC822.MailboxAddress("sender", "sender@example.com"),
                new Convey.RFC822.MailboxAddress("reply-to", "reply-to@example.com")
            )
        );

        assert_non_null(originator);
        assert_equal(originator.name, "sender");
        assert_equal(originator.address, "sender@example.com");
    }

    public void reply_to_originator() throws GLib.Error {
        Convey.RFC822.MailboxAddress? originator = get_primary_originator(
            new_email(
                null,
                null,
                new Convey.RFC822.MailboxAddress("reply-to", "reply-to@example.com")
            )
        );

        assert_non_null(originator);
        assert_equal(originator.name, "reply-to");
        assert_equal(originator.address, "reply-to@example.com");
    }

    public void reply_to_via_originator() throws GLib.Error {
        Convey.RFC822.MailboxAddress? originator = get_primary_originator(
            new_email(
                new Convey.RFC822.MailboxAddress("test via bot", "bot@example.com"),
                null,
                new Convey.RFC822.MailboxAddress("test", "test@example.com")
            )
        );

        assert_non_null(originator);
        assert_equal(originator.name, "test");
        assert_equal(originator.address, "test@example.com");
    }

    public void plain_via_originator() throws GLib.Error {
        Convey.RFC822.MailboxAddress? originator = get_primary_originator(
            new_email(
                new Convey.RFC822.MailboxAddress("test via bot", "bot@example.com"),
                null,
                null
            )
        );

        assert_non_null(originator);
        assert_equal(originator.name, "test");
        assert_equal(originator.address, "bot@example.com");
    }

    public void empty_search_query() throws GLib.Error {
        var test_article = new SearchExpressionFactory(
            this.config.get_search_strategy(), this.account
        );
        assert_collection(test_article.parse_query("")).is_empty();
    }

    public void plain_search_terms() throws GLib.Error {
        var test_article = new SearchExpressionFactory(
            this.config.get_search_strategy(), this.account
        );

        var simple1 = test_article.parse_query("hello");
        assert_collection(simple1).size(1);
        assert_true(simple1[0] is Convey.SearchQuery.EmailTextTerm);
        var text1 = simple1[0] as Convey.SearchQuery.EmailTextTerm;
        assert_true(text1.target == ALL);
        assert_true(text1.matching_strategy == CONSERVATIVE);
        assert_collection(text1.terms).size(1).contains("hello");

        var simple2 = test_article.parse_query("h");
        assert_collection(simple2).size(1);
        assert_true(simple2[0] is Convey.SearchQuery.EmailTextTerm);
        var text2 = simple2[0] as Convey.SearchQuery.EmailTextTerm;
        assert_collection(text2.terms).size(1).contains("h");

        var simple3 = test_article.parse_query(" h");
        assert_collection(simple3).size(1);
        assert_true(simple3[0] is Convey.SearchQuery.EmailTextTerm);
        var text3 = simple3[0] as Convey.SearchQuery.EmailTextTerm;
        assert_collection(text3.terms).size(1).contains("h");

        var simple4 = test_article.parse_query("h ");
        assert_collection(simple4).size(1);
        assert_true(simple4[0] is Convey.SearchQuery.EmailTextTerm);
        var text4 = simple4[0] as Convey.SearchQuery.EmailTextTerm;
        assert_collection(text4.terms).size(1).contains("h");
    }

    public void continuation_search_terms() throws GLib.Error {
        var test_article = new SearchExpressionFactory(
            this.config.get_search_strategy(),
            this.account
        );

        var simple1 = test_article.parse_query("hello-there");
        assert_collection(simple1).size(1);
        assert_true(simple1[0] is Convey.SearchQuery.EmailTextTerm);
        var text1 = simple1[0] as Convey.SearchQuery.EmailTextTerm;
        assert_collection(text1.terms).size(1).contains("hello-there");

        var simple2 = test_article.parse_query("hello-");
        assert_collection(simple2).size(1);
        assert_true(simple2[0] is Convey.SearchQuery.EmailTextTerm);
        var text2 = simple2[0] as Convey.SearchQuery.EmailTextTerm;
        assert_collection(text2.terms).size(1).contains("hello-");

        var simple3 = test_article.parse_query("test@example.com");
        assert_collection(simple2).size(1);
        assert_true(simple3[0] is Convey.SearchQuery.EmailTextTerm);
        var text3 = simple3[0] as Convey.SearchQuery.EmailTextTerm;
        assert_collection(text3.terms).size(1).contains("test@example.com");
    }

    public void i18n_search_terms() throws GLib.Error {
        var test_article = new SearchExpressionFactory(
            this.config.get_search_strategy(),
            this.account
        );

        var thai = test_article.parse_query("ภาษาไทย");
        assert_collection(thai).size(2);
        assert_true(thai[0] is Convey.SearchQuery.EmailTextTerm);
        assert_true(thai[1] is Convey.SearchQuery.EmailTextTerm);
        assert_collection(
            ((Convey.SearchQuery.EmailTextTerm) thai[0]).terms
        ).size(1).contains("ภาษา");
        assert_collection(
            ((Convey.SearchQuery.EmailTextTerm) thai[1]).terms
        ).size(1).contains("ไทย");

        var chinese = test_article.parse_query("男子去");
        assert_collection(chinese).size(2);
        assert_true(chinese[0] is Convey.SearchQuery.EmailTextTerm);
        assert_true(chinese[1] is Convey.SearchQuery.EmailTextTerm);
        assert_collection(
            ((Convey.SearchQuery.EmailTextTerm) chinese[0]).terms
        ).size(1).contains("男子");
        assert_collection(
            ((Convey.SearchQuery.EmailTextTerm) chinese[1]).terms
        ).size(1).contains("去");
    }

    public void multiple_search_terms() throws GLib.Error {
        var test_article = new SearchExpressionFactory(
            this.config.get_search_strategy(), this.account
        );

        var multiple = test_article.parse_query("hello there");
        assert_collection(multiple).size(2);
        assert_true(multiple[0] is Convey.SearchQuery.EmailTextTerm);
        assert_true(multiple[1] is Convey.SearchQuery.EmailTextTerm);
        assert_collection(
            ((Convey.SearchQuery.EmailTextTerm) multiple[0]).terms
        ).size(1).contains("hello");
        assert_collection(
            ((Convey.SearchQuery.EmailTextTerm) multiple[1]).terms
        ).size(1).contains("there");
    }

    public void quoted_search_terms() throws GLib.Error {
        var test_article = new SearchExpressionFactory(
            this.config.get_search_strategy(), this.account
        );

        var simple1 = test_article.parse_query("\"hello\"");
        assert_collection(simple1).size(1);
        assert_true(simple1[0] is Convey.SearchQuery.EmailTextTerm);
        var text1 = simple1[0] as Convey.SearchQuery.EmailTextTerm;
        assert_true(text1.target == ALL);
        assert_true(text1.matching_strategy == EXACT);
        assert_collection(text1.terms).size(1).contains("hello");

        var simple2 = test_article.parse_query("\"h\"");
        assert_collection(simple2).size(1);
        assert_true(simple2[0] is Convey.SearchQuery.EmailTextTerm);
        var text2 = simple2[0] as Convey.SearchQuery.EmailTextTerm;
        assert_collection(text2.terms).size(1).contains("h");

        var simple3 = test_article.parse_query(" \"h\"");
        assert_collection(simple3).size(1);
        assert_true(simple3[0] is Convey.SearchQuery.EmailTextTerm);
        var text3 = simple3[0] as Convey.SearchQuery.EmailTextTerm;
        assert_collection(text3.terms).size(1).contains("h");

        var simple4 = test_article.parse_query("\"h");
        assert_collection(simple4).size(1);
        assert_true(simple4[0] is Convey.SearchQuery.EmailTextTerm);
        var text4 = simple4[0] as Convey.SearchQuery.EmailTextTerm;
        assert_collection(text4.terms).size(1).contains("h");

        var simple5 = test_article.parse_query("\"h\" ");
        assert_collection(simple5).size(1);
        assert_true(simple5[0] is Convey.SearchQuery.EmailTextTerm);
        var text5 = simple5[0] as Convey.SearchQuery.EmailTextTerm;
        assert_collection(text5.terms).size(1).contains("h");

        var simple6 = test_article.parse_query("\"hello there\"");
        assert_collection(simple6).size(1);
        assert_true(simple6[0] is Convey.SearchQuery.EmailTextTerm);
        var text6 = simple6[0] as Convey.SearchQuery.EmailTextTerm;
        assert_collection(text6.terms).size(1).contains("hello there");
    }

    public void text_op_terms() throws GLib.Error {
        var test_article = new SearchExpressionFactory(
            this.config.get_search_strategy(), this.account
        );

        var simple_body = test_article.parse_query("body:hello");
        assert_collection(simple_body).size(1);
        assert_true(simple_body[0] is Convey.SearchQuery.EmailTextTerm, "type");
        var text_body = simple_body[0] as Convey.SearchQuery.EmailTextTerm;
        assert_true(text_body.target == BODY, "target");
        assert_true(text_body.matching_strategy == CONSERVATIVE, "strategy");
        assert_collection(text_body.terms).size(1).contains("hello");

        var simple_body_quoted = test_article.parse_query("body:\"hello\"");
        assert_collection(simple_body_quoted).size(1);
        assert_true(simple_body_quoted[0] is Convey.SearchQuery.EmailTextTerm);
        var text_body_quoted = simple_body_quoted[0] as Convey.SearchQuery.EmailTextTerm;
        assert_true(text_body_quoted.target == BODY);
        assert_true(text_body_quoted.matching_strategy == EXACT);
        assert_collection(text_body_quoted.terms).size(1).contains("hello");

        var simple_attach_name = test_article.parse_query("attachment:hello");
        assert_collection(simple_attach_name).size(1);
        assert_true(simple_attach_name[0] is Convey.SearchQuery.EmailTextTerm);
        var text_attch_name = simple_attach_name[0] as Convey.SearchQuery.EmailTextTerm;
        assert_true(text_attch_name.target == ATTACHMENT_NAME);

        var simple_bcc = test_article.parse_query("bcc:hello");
        assert_collection(simple_bcc).size(1);
        assert_true(simple_bcc[0] is Convey.SearchQuery.EmailTextTerm);
        var text_bcc = simple_bcc[0] as Convey.SearchQuery.EmailTextTerm;
        assert_true(text_bcc.target == BCC);

        var simple_cc = test_article.parse_query("cc:hello");
        assert_collection(simple_cc).size(1);
        assert_true(simple_cc[0] is Convey.SearchQuery.EmailTextTerm);
        var text_cc = simple_cc[0] as Convey.SearchQuery.EmailTextTerm;
        assert_true(text_cc.target == CC);

        var simple_from = test_article.parse_query("from:hello");
        assert_collection(simple_from).size(1);
        assert_true(simple_from[0] is Convey.SearchQuery.EmailTextTerm);
        var text_from = simple_from[0] as Convey.SearchQuery.EmailTextTerm;
        assert_true(text_from.target == FROM);

        var simple_subject = test_article.parse_query("subject:hello");
        assert_collection(simple_subject).size(1);
        assert_true(simple_subject[0] is Convey.SearchQuery.EmailTextTerm);
        var text_subject = simple_subject[0] as Convey.SearchQuery.EmailTextTerm;
        assert_true(text_subject.target == SUBJECT);

        var simple_to = test_article.parse_query("to:hello");
        assert_collection(simple_to).size(1);
        assert_true(simple_to[0] is Convey.SearchQuery.EmailTextTerm);
        var text_to = simple_to[0] as Convey.SearchQuery.EmailTextTerm;
        assert_true(text_to.target == TO);
    }

    public void text_op_single_me_terms() throws GLib.Error {
        var test_article = new SearchExpressionFactory(
            this.config.get_search_strategy(), this.account
        );

        var simple_to = test_article.parse_query("to:me");
        assert_collection(simple_to).size(1);
        assert_true(simple_to[0] is Convey.SearchQuery.EmailTextTerm);
        var text_to = simple_to[0] as Convey.SearchQuery.EmailTextTerm;
        assert_true(text_to.target == TO);
        assert_true(text_to.matching_strategy == EXACT);
        assert_collection(text_to.terms).size(1).contains("test@example.com");

        var simple_cc = test_article.parse_query("cc:me");
        assert_collection(simple_cc).size(1);
        assert_true(simple_cc[0] is Convey.SearchQuery.EmailTextTerm);
        var text_cc = simple_cc[0] as Convey.SearchQuery.EmailTextTerm;
        assert_true(text_cc.target == CC);
        assert_true(text_cc.matching_strategy == EXACT);
        assert_collection(text_cc.terms).size(1).contains("test@example.com");

        var simple_bcc = test_article.parse_query("bcc:me");
        assert_collection(simple_bcc).size(1);
        assert_true(simple_bcc[0] is Convey.SearchQuery.EmailTextTerm);
        var text_bcc = simple_bcc[0] as Convey.SearchQuery.EmailTextTerm;
        assert_true(text_bcc.target == BCC);
        assert_true(text_bcc.matching_strategy == EXACT);
        assert_collection(text_bcc.terms).size(1).contains("test@example.com");

        var simple_from = test_article.parse_query("from:me");
        assert_collection(simple_from).size(1);
        assert_true(simple_from[0] is Convey.SearchQuery.EmailTextTerm);
        var text_from = simple_from[0] as Convey.SearchQuery.EmailTextTerm;
        assert_true(text_from.target == FROM);
        assert_true(text_from.matching_strategy == EXACT);
        assert_collection(text_from.terms).size(1).contains("test@example.com");
    }

    public void text_op_multiple_me_terms() throws GLib.Error {
        this.account.append_sender(
            new Convey.RFC822.MailboxAddress("test2", "test2@example.com")
        );
        var test_article = new SearchExpressionFactory(
            this.config.get_search_strategy(), this.account
        );

        var to = test_article.parse_query("to:me");
        assert_collection(to).size(1);
        assert_true(to[0] is Convey.SearchQuery.EmailTextTerm);
        var text_to = to[0] as Convey.SearchQuery.EmailTextTerm;
        assert_true(text_to.target == TO);
        assert_true(text_to.matching_strategy == EXACT);
        assert_collection(text_to.terms).size(2).contains(
            "test@example.com"
        ).contains(
            "test@example.com"
        );
    }

    public void boolean_op_terms() throws GLib.Error {
        var test_article = new SearchExpressionFactory(
            this.config.get_search_strategy(), this.account
        );

        var simple_unread = test_article.parse_query("is:unread");
        assert_true(simple_unread[0] is Convey.SearchQuery.EmailFlagTerm);
        var bool_unread = simple_unread[0] as Convey.SearchQuery.EmailFlagTerm;
        assert_true(
            bool_unread.value.equal_to(Convey.EmailFlags.UNREAD), "unread flag"
        );
        assert_false(bool_unread.is_negated, "unread negated");

        var simple_read = test_article.parse_query("is:read");
        assert_true(simple_read[0] is Convey.SearchQuery.EmailFlagTerm);
        var bool_read = simple_read[0] as Convey.SearchQuery.EmailFlagTerm;
        assert_true(
            bool_read.value.equal_to(Convey.EmailFlags.UNREAD), "read flag"
        );
        assert_true(bool_read.is_negated, "read negated");

        var simple_starred = test_article.parse_query("is:starred");
        assert_true(simple_starred[0] is Convey.SearchQuery.EmailFlagTerm);
        var bool_starred = simple_starred[0] as Convey.SearchQuery.EmailFlagTerm;
        assert_true(
            bool_starred.value.equal_to(Convey.EmailFlags.FLAGGED), "starred flag"
        );
        assert_false(bool_starred.is_negated, "starred negated");
    }

    public void invalid_op_terms() throws GLib.Error {
        var test_article = new SearchExpressionFactory(
            this.config.get_search_strategy(), this.account
        );

        var simple1 = test_article.parse_query("body:");
        assert_collection(simple1).size(1);
        assert_true(simple1[0] is Convey.SearchQuery.EmailTextTerm);
        var text1 = simple1[0] as Convey.SearchQuery.EmailTextTerm;
        assert_true(text1.target == ALL);
        assert_true(text1.matching_strategy == CONSERVATIVE);
        assert_collection(text1.terms).size(1).contains("body:");

        var simple2 = test_article.parse_query("blarg:");
        assert_collection(simple2).size(1);
        assert_true(simple2[0] is Convey.SearchQuery.EmailTextTerm);
        var text2 = simple2[0] as Convey.SearchQuery.EmailTextTerm;
        assert_true(text2.target == ALL);
        assert_true(text2.matching_strategy == CONSERVATIVE);
        assert_collection(text2.terms).size(1).contains("blarg:");

        var simple3 = test_article.parse_query("blarg:hello");
        assert_collection(simple3).size(1);
        assert_true(simple3[0] is Convey.SearchQuery.EmailTextTerm);
        var text3 = simple3[0] as Convey.SearchQuery.EmailTextTerm;
        assert_true(text3.target == ALL);
        assert_true(text3.matching_strategy == CONSERVATIVE);
        assert_collection(text3.terms).size(1).contains("blarg:hello");
    }

    private Convey.Email new_email(Convey.RFC822.MailboxAddress? from,
                                  Convey.RFC822.MailboxAddress? sender,
                                  Convey.RFC822.MailboxAddress? reply_to)
        throws GLib.Error {
        Convey.Email email = new Convey.Email(new Mock.EmailIdentifer(1));
        email.set_originators(
            from != null
            ? new Convey.RFC822.MailboxAddresses(Convey.Collection.single(from))
            : null,
            sender,
            reply_to != null
            ? new Convey.RFC822.MailboxAddresses(Convey.Collection.single(reply_to))
            : null
        );
        return email;
    }

}


/** Synthetic matching tests: no Configuration, engine, bus or mail store. */
public class Util.Email.RecipientAliasesTest : TestCase {

    private Convey.AccountInformation account;

    public RecipientAliasesTest() {
        base("Util.Email.RecipientAliasesTest");
        add_test("to_and_cc", to_and_cc);
        add_test("duplicates_case_and_display_names", duplicates_case_and_display_names);
        add_test("whole_addresses_only", whole_addresses_only);
        add_test("missing_fields", missing_fields);
        add_test("bcc_and_raw_headers_ignored", bcc_and_raw_headers_ignored);
        add_test("incoming_survives_own_reply", incoming_survives_own_reply);
        add_test("own_originators_and_self_send", own_originators_and_self_send);
        add_test("deleted_draft_and_outbox_sent", deleted_draft_and_outbox_sent);
        add_test("known_outgoing_ids", known_outgoing_ids);
        add_test("account_isolation", account_isolation);
        add_test("stable_order", stable_order);
        add_test("alias_edit_and_undo", alias_edit_and_undo);
        add_test("loaded_union_append_and_trim", loaded_union_append_and_trim);
        add_test("badge_colours_stable_and_unique", badge_colours_stable_and_unique);
        add_test("badge_colours_duplicates_and_overflow", badge_colours_duplicates_and_overflow);
    }

    public override void set_up() {
        this.account = new Convey.AccountInformation(
            "alias-test", OTHER, new Mock.CredentialsMediator(),
            new Convey.RFC822.MailboxAddress("Primary", "test@example.com")
        );
        this.account.append_sender(
            new Convey.RFC822.MailboxAddress("Alias", "alias@example.com")
        );
    }

    public override void tear_down() {
        this.account = null;
    }

    public void to_and_cc() throws GLib.Error {
        var to = new_email(1, "test@example.com");
        assert_addresses(match(to), { "test@example.com" });

        var cc = new_email(2, null, "alias@example.com");
        assert_addresses(match(cc), { "alias@example.com" });

        var both = new_email(3, "test@example.com", "alias@example.com");
        assert_addresses(match(both), { "alias@example.com", "test@example.com" });
    }

    public void duplicates_case_and_display_names() throws GLib.Error {
        var email = new_email(
            1, "\"Untrusted <b>name</b>\" <ALIAS@EXAMPLE.COM>, alias@example.com",
            "Other name <alias@example.com>, TEST@example.com"
        );
        var emails = new Gee.ArrayList<Convey.Email>();
        emails.add(email);
        emails.add(new_email(2, "Alias again <Alias@Example.Com>"));
        var matches = get_recipient_aliases(emails, this.account.sender_mailboxes);
        assert_addresses(matches, { "alias@example.com", "test@example.com" });
        // Return the configured identity, not an untrusted recipient name.
        assert_equal(matches[0].name, "Alias");
    }

    public void whole_addresses_only() throws GLib.Error {
        var email = new_email(
            1, "nottest@example.com, test@example.com.evil, test+tag@example.com, " +
               "t.est@example.com, test@other.example, \"test@example.com\" <other@example.net>"
        );
        assert_collection(match(email)).is_empty();

        // Plus tags and dots are literal identities, not normalised away.
        this.account.append_sender(
            new Convey.RFC822.MailboxAddress(null, "test+tag@example.com")
        );
        this.account.append_sender(
            new Convey.RFC822.MailboxAddress(null, "t.est@example.com")
        );
        assert_addresses(match(email), { "t.est@example.com", "test+tag@example.com" });
    }

    public void missing_fields() throws GLib.Error {
        var emails = new Gee.ArrayList<Convey.Email>();
        assert_collection(get_recipient_aliases(emails, null)).is_empty();
        assert_collection(get_recipient_aliases(
            emails, this.account.sender_mailboxes
        )).is_empty();
        emails.add(new Convey.Email(new Mock.EmailIdentifer(1)));
        emails.add(new_email(2, "alias@example.com", null, null));
        var empty_from = new_email(3, "alias@example.com", null, null);
        empty_from.set_originators(
            new Convey.RFC822.MailboxAddresses(), null,
            new Convey.RFC822.MailboxAddresses.from_rfc822_string("outside@example.net")
        );
        emails.add(empty_from);
        emails.add(new_email(4)); // Originator, but no recipients or flags.
        assert_collection(get_recipient_aliases(
            emails, this.account.sender_mailboxes
        )).is_empty();

        var sender_only = new_email(5, "alias@example.com", null, null);
        sender_only.set_originators(
            null, new Convey.RFC822.MailboxAddress(null, "outside@example.net"), null
        );
        assert_addresses(match(sender_only), { "alias@example.com" });
        assert_collection(get_recipient_aliases(
            Convey.Collection.single(sender_only),
            new Gee.ArrayList<Convey.RFC822.MailboxAddress>()
        )).is_empty();
    }

    public void bcc_and_raw_headers_ignored() throws GLib.Error {
        var email = new_email(1);
        email.set_receivers(
            null, null,
            new Convey.RFC822.MailboxAddresses.from_rfc822_string("alias@example.com")
        );
        email.set_message_header(new Convey.RFC822.Header(
            new Convey.Memory.StringBuffer(
                "Delivered-To: alias@example.com\r\n" +
                "X-Original-To: test@example.com\r\n" +
                "To: alias@example.com\r\n\r\n"
            )
        ));
        assert_collection(match(email)).is_empty();
    }

    public void incoming_survives_own_reply() throws GLib.Error {
        var emails = new Gee.ArrayList<Convey.Email>();
        var incoming = new_email(1, "alias@example.com");
        emails.add(incoming);
        // This reply must not add the primary identity or erase the alias.
        var reply = new_email(2, "test@example.com", null, "alias@example.com");
        emails.add(reply);
        assert_addresses(get_recipient_aliases(
            emails, this.account.sender_mailboxes
        ), { "alias@example.com" });
        emails.clear();
        emails.add(reply);
        emails.add(incoming);
        assert_addresses(get_recipient_aliases(
            emails, this.account.sender_mailboxes
        ), { "alias@example.com" });
    }

    public void own_originators_and_self_send() throws GLib.Error {
        assert_collection(match(new_email(
            1, "test@example.com", null, "TEST@EXAMPLE.COM"
        ))).is_empty();

        var own_sender = new_email(2, "alias@example.com");
        own_sender.set_originators(
            own_sender.from,
            new Convey.RFC822.MailboxAddress("Own sender", "test@example.com"),
            null
        );
        assert_collection(match(own_sender)).is_empty();

        var multiple_from = new_email(
            3, "alias@example.com", null, "outside@example.net, test@example.com"
        );
        assert_collection(match(multiple_from)).is_empty();

        var own_sender_only = new_email(4, "alias@example.com", null, null);
        own_sender_only.set_originators(
            null, new Convey.RFC822.MailboxAddress(null, "test@example.com"), null
        );
        assert_collection(match(own_sender_only)).is_empty();

        // Reply-To is not an originator, and must not suppress a match.
        var reply_to = new_email(5, "alias@example.com");
        reply_to.set_originators(
            reply_to.from, null,
            new Convey.RFC822.MailboxAddresses.from_rfc822_string("test@example.com")
        );
        assert_addresses(match(reply_to), { "alias@example.com" });
    }

    public void deleted_draft_and_outbox_sent() throws GLib.Error {
        var deleted = new_email(1, "alias@example.com");
        deleted.set_flags(new Convey.EmailFlags.with(Convey.EmailFlags.DELETED));
        var draft = new_email(2, "test@example.com");
        draft.set_flags(new Convey.EmailFlags.with(Convey.EmailFlags.DRAFT));
        var sent = new_email(3, "alias@example.com");
        sent.set_flags(new Convey.EmailFlags.with(Convey.EmailFlags.OUTBOX_SENT));
        var emails = new Gee.ArrayList<Convey.Email>();
        emails.add(deleted);
        emails.add(draft);
        emails.add(sent);
        assert_collection(get_recipient_aliases(
            emails, this.account.sender_mailboxes
        )).is_empty();

        // Recompute from the current flags, not from stale cached matches.
        deleted.set_flags(new Convey.EmailFlags());
        assert_addresses(get_recipient_aliases(
            emails, this.account.sender_mailboxes
        ), { "alias@example.com" });
        deleted.set_flags(new Convey.EmailFlags.with(Convey.EmailFlags.DELETED));
        assert_collection(get_recipient_aliases(
            emails, this.account.sender_mailboxes
        )).is_empty();
    }

    public void known_outgoing_ids() throws GLib.Error {
        var emails = new Gee.ArrayList<Convey.Email>();
        emails.add(new_email(1, "alias@example.com"));
        // Even an external From is excluded if the model knows it is outgoing.
        emails.add(new_email(2, "test@example.com"));
        var excluded = new Gee.HashSet<Convey.EmailIdentifier>();
        excluded.add(new Mock.EmailIdentifer(2));
        assert_addresses(get_recipient_aliases(
            emails, this.account.sender_mailboxes, excluded
        ), { "alias@example.com" });
    }

    public void account_isolation() throws GLib.Error {
        var other = new Convey.AccountInformation(
            "other-test", OTHER, new Mock.CredentialsMediator(),
            new Convey.RFC822.MailboxAddress(null, "other@example.com")
        );
        var emails = Convey.Collection.single(new_email(1, "other@example.com"));
        assert_collection(get_recipient_aliases(
            emails, this.account.sender_mailboxes
        )).is_empty();
        assert_addresses(get_recipient_aliases(
            emails, other.sender_mailboxes
        ), { "other@example.com" });
    }

    public void stable_order() throws GLib.Error {
        var emails = new Gee.ArrayList<Convey.Email>();
        emails.add(new_email(1, "test@example.com"));
        emails.add(new_email(2, "alias@example.com"));
        var configured = new Gee.ArrayList<Convey.RFC822.MailboxAddress>();
        configured.add_all(this.account.sender_mailboxes);
        // Also handle duplicate configured addresses deterministically.
        configured.add(new Convey.RFC822.MailboxAddress(null, "ALIAS@EXAMPLE.COM"));
        string[] expected = { "ALIAS@EXAMPLE.COM", "test@example.com" };
        assert_addresses(get_recipient_aliases(emails, configured), expected);
        var reordered = new Gee.ArrayList<Convey.RFC822.MailboxAddress>();
        foreach (var mailbox in configured) {
            reordered.insert(0, mailbox);
        }
        var first = emails.remove_at(0);
        emails.add(first);
        assert_addresses(get_recipient_aliases(emails, reordered), expected);
        // Input identity rank remains untouched.
        assert_equal(this.account.primary_mailbox.address, "test@example.com");
    }

    public void alias_edit_and_undo() throws GLib.Error {
        var email = new_email(1, "alias@example.com");
        var original = this.account.sender_mailboxes[1];
        this.account.replace_sender(
            1, new Convey.RFC822.MailboxAddress(null, "edited@example.com")
        );
        assert_collection(match(email)).is_empty();
        this.account.replace_sender(1, original);
        assert_addresses(match(email), { "alias@example.com" });
        this.account.remove_sender(original);
        assert_collection(match(email)).is_empty();
        this.account.append_sender(original);
        assert_addresses(match(email), { "alias@example.com" });
    }

    public void loaded_union_append_and_trim() throws GLib.Error {
        var emails = new Gee.ArrayList<Convey.Email>();
        var primary = new_email(1, "test@example.com");
        var alias = new_email(2, null, "alias@example.com");
        emails.add(primary);
        assert_addresses(get_recipient_aliases(
            emails, this.account.sender_mailboxes
        ), { "test@example.com" });
        emails.add(alias);
        assert_addresses(get_recipient_aliases(
            emails, this.account.sender_mailboxes
        ), { "alias@example.com", "test@example.com" });
        emails.remove(primary);
        assert_addresses(get_recipient_aliases(
            emails, this.account.sender_mailboxes
        ), { "alias@example.com" });
        emails.clear();
        assert_collection(get_recipient_aliases(
            emails, this.account.sender_mailboxes
        )).is_empty();
    }

    public void badge_colours_stable_and_unique() throws GLib.Error {
        var addresses = new Gee.ArrayList<Convey.RFC822.MailboxAddress>();
        for (int i = 0; i < 12; i++) {
            addresses.add(new Convey.RFC822.MailboxAddress(
                "Name", "alias%d@example.com".printf(i)
            ));
        }
        var reversed = new Gee.ArrayList<Convey.RFC822.MailboxAddress>();
        for (int i = addresses.size - 1; i >= 0; i--) {
            reversed.add(addresses[i]);
        }
        var colours = new Gee.HashSet<uint>();
        foreach (var address in addresses) {
            uint colour = get_recipient_alias_color(address, addresses);
            assert_true(colour < 12);
            assert_true(colours.add(colour));
            assert_equal<uint?>(colour, get_recipient_alias_color(address, reversed));
            var uppercase = new Convey.RFC822.MailboxAddress(
                "Different name", address.address.up()
            );
            assert_equal<uint?>(colour, get_recipient_alias_color(uppercase, addresses));
        }
    }

    public void badge_colours_duplicates_and_overflow() throws GLib.Error {
        var addresses = new Gee.ArrayList<Convey.RFC822.MailboxAddress>();
        var alias = new Convey.RFC822.MailboxAddress(null, "alias@example.com");
        addresses.add(alias);
        uint before = get_recipient_alias_color(alias, addresses);
        addresses.add(new Convey.RFC822.MailboxAddress("Duplicate", "ALIAS@example.com"));
        assert_equal<uint?>(before, get_recipient_alias_color(alias, addresses));
        for (int i = 0; i < 30; i++) {
            addresses.add(new Convey.RFC822.MailboxAddress(
                null, "additional%d@example.com".printf(i)
            ));
        }
        foreach (var address in addresses) {
            assert_true(get_recipient_alias_color(address, addresses) < 12);
        }
        assert_true(get_recipient_alias_color(alias, null) < 12);
    }

    private Gee.List<Convey.RFC822.MailboxAddress> match(Convey.Email email) {
        return get_recipient_aliases(
            Convey.Collection.single(email), this.account.sender_mailboxes
        );
    }

    private void assert_addresses(Gee.List<Convey.RFC822.MailboxAddress> matches,
                                  string[] expected) throws GLib.Error {
        assert_equal<int?>(matches.size, expected.length);
        for (int i = 0; i < expected.length; i++) {
            assert_equal(matches[i].address, expected[i]);
        }
    }

    private Convey.Email new_email(int id,
                                   string? to = null,
                                   string? cc = null,
                                   string? from = "outside@example.net")
        throws GLib.Error {
        var email = new Convey.Email(new Mock.EmailIdentifer(id));
        email.set_originators(parse_addresses(from), null, null);
        email.set_receivers(parse_addresses(to), parse_addresses(cc), null);
        return email;
    }

    private Convey.RFC822.MailboxAddresses? parse_addresses(string? text)
        throws GLib.Error {
        return text != null
            ? new Convey.RFC822.MailboxAddresses.from_rfc822_string(text)
            : null;
    }
}
