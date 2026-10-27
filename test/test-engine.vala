/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2016-2018 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

int main(string[] args) {
    /*
     * Initialise all the things.
     */

    GLib.Intl.setlocale(LocaleCategory.ALL, "C.UTF-8");

    Test.init(ref args);

    GriabuntuMail.RFC822.init();
    GriabuntuMail.HTML.init();
    GriabuntuMail.Logging.init();
    if (GLib.Test.verbose()) {
        GLib.Log.set_writer_func(GriabuntuMail.Logging.default_log_writer);
        GriabuntuMail.Logging.log_to(GLib.stdout);
    }

    /*
     * Hook up all tests into appropriate suites
     */

    TestSuite engine = new TestSuite("engine");

    engine.add_suite(new GriabuntuMail.AccountInformationTest().steal_suite());
    engine.add_suite(new GriabuntuMail.AttachmentTest().steal_suite());
    engine.add_suite(new GriabuntuMail.ContactHarvesterImplTest().steal_suite());
    engine.add_suite(new GriabuntuMail.EngineTest().steal_suite());
    engine.add_suite(new GriabuntuMail.FolderPathTest().steal_suite());
    engine.add_suite(new GriabuntuMail.IdleManagerTest().steal_suite());
    engine.add_suite(new GriabuntuMail.TimeoutManagerTest().steal_suite());
    engine.add_suite(new GriabuntuMail.TlsNegotiationMethodTest().steal_suite());

    // Graph engine tests share a Soup.Server fixture
    engine.add_suite(new GriabuntuMail.Graph.ClientTest().steal_suite());
    engine.add_suite(new GriabuntuMail.Graph.AccountTest().steal_suite());
    engine.add_suite(new GriabuntuMail.Graph.FolderTest().steal_suite());
    engine.add_suite(new GriabuntuMail.App.ConversationTest().steal_suite());
    engine.add_suite(new GriabuntuMail.App.ConversationSetTest().steal_suite());
    // Depends on ConversationTest and ConversationSetTest passing
    engine.add_suite(new GriabuntuMail.App.ConversationMonitorTest().steal_suite());
    engine.add_suite(new GriabuntuMail.Ascii.Test().steal_suite());
    engine.add_suite(new GriabuntuMail.ConfigFileTest().steal_suite());
    engine.add_suite(new GriabuntuMail.Db.DatabaseTest().steal_suite());
    engine.add_suite(new GriabuntuMail.Db.VersionedDatabaseTest().steal_suite());
    engine.add_suite(new GriabuntuMail.HTML.UtilTest().steal_suite());

    // Other IMAP tests rely on these working, so test them first
    engine.add_suite(new GriabuntuMail.Imap.DataFormatTest().steal_suite());

    engine.add_suite(new GriabuntuMail.Imap.CreateCommandTest().steal_suite());
    engine.add_suite(new GriabuntuMail.Imap.RenameCommandTest().steal_suite());
    engine.add_suite(new GriabuntuMail.Imap.FetchCommandTest().steal_suite());
    engine.add_suite(new GriabuntuMail.Imap.FetchDataDecoderTest().steal_suite());
    engine.add_suite(new GriabuntuMail.Imap.ListParameterTest().steal_suite());
    engine.add_suite(new GriabuntuMail.Imap.MailboxSpecifierTest().steal_suite());
    engine.add_suite(new GriabuntuMail.Imap.NamespaceResponseTest().steal_suite());

    // Depends on IMAP commands working
    engine.add_suite(new GriabuntuMail.Imap.DeserializerTest().steal_suite());
    engine.add_suite(new GriabuntuMail.Imap.ClientConnectionTest().steal_suite());
    engine.add_suite(new GriabuntuMail.Imap.ClientSessionTest().steal_suite());

    engine.add_suite(new GriabuntuMail.ImapDB.AccountTest().steal_suite());
    engine.add_suite(new GriabuntuMail.ImapDB.AttachmentTest().steal_suite());
    engine.add_suite(new GriabuntuMail.ImapDB.AttachmentIoTest().steal_suite());
    engine.add_suite(new GriabuntuMail.ImapDB.DatabaseTest().steal_suite());
    engine.add_suite(new GriabuntuMail.ImapDB.EmailIdentifierTest().steal_suite());
    engine.add_suite(new GriabuntuMail.ImapDB.FolderTest().steal_suite());

    // Depends on ImapDB working
    engine.add_suite(new GriabuntuMail.FtsSearchQueryTest().steal_suite());

    engine.add_suite(new GriabuntuMail.ImapEngine.AccountProcessorTest().steal_suite());
    engine.add_suite(new GriabuntuMail.ImapEngine.GenericAccountTest().steal_suite());

    // Depends on ImapDb.Database working correctly
    engine.add_suite(new GriabuntuMail.ContactStoreImplTest().steal_suite());

    engine.add_suite(new GriabuntuMail.Inet.Test().steal_suite());
    engine.add_suite(new GriabuntuMail.Mime.ContentTypeTest().steal_suite());
    engine.add_suite(new GriabuntuMail.Outbox.EmailIdentifierTest().steal_suite());
    engine.add_suite(new GriabuntuMail.RFC822.MailboxAddressTest().steal_suite());
    engine.add_suite(new GriabuntuMail.RFC822.MailboxAddressesTest().steal_suite());
    engine.add_suite(new GriabuntuMail.RFC822.MessageDataTest().steal_suite());
    engine.add_suite(new GriabuntuMail.RFC822.PartTest().steal_suite());
    engine.add_suite(new GriabuntuMail.RFC822.Utils.Test().steal_suite());
    // Message requires all of the rest of the package working, so put
    // last
    engine.add_suite(new GriabuntuMail.RFC822.MessageTest().steal_suite());
    engine.add_suite(new GriabuntuMail.String.Test().steal_suite());
    engine.add_suite(new GriabuntuMail.EmailTest().steal_suite());
    engine.add_suite(new GriabuntuMail.ComposedEmailTest().steal_suite());

    /*
     * Run the tests
     */
    unowned TestSuite root = TestSuite.get_root();
    root.add_suite((owned) engine);

    MainLoop loop = new MainLoop ();

    int ret = -1;
    Idle.add(() => {
            ret = Test.run();
            loop.quit();
            return false;
        });

    loop.run();
    return ret;
}
