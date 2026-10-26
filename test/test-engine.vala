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

    Convey.RFC822.init();
    Convey.HTML.init();
    Convey.Logging.init();
    if (GLib.Test.verbose()) {
        GLib.Log.set_writer_func(Convey.Logging.default_log_writer);
        Convey.Logging.log_to(GLib.stdout);
    }

    /*
     * Hook up all tests into appropriate suites
     */

    TestSuite engine = new TestSuite("engine");

    engine.add_suite(new Convey.AccountInformationTest().steal_suite());
    engine.add_suite(new Convey.AttachmentTest().steal_suite());
    engine.add_suite(new Convey.ContactHarvesterImplTest().steal_suite());
    engine.add_suite(new Convey.EngineTest().steal_suite());
    engine.add_suite(new Convey.FolderPathTest().steal_suite());
    engine.add_suite(new Convey.IdleManagerTest().steal_suite());
    engine.add_suite(new Convey.TimeoutManagerTest().steal_suite());
    engine.add_suite(new Convey.TlsNegotiationMethodTest().steal_suite());

    // Graph engine tests share a Soup.Server fixture
    engine.add_suite(new Convey.Graph.ClientTest().steal_suite());
    engine.add_suite(new Convey.Graph.AccountTest().steal_suite());
    engine.add_suite(new Convey.Graph.FolderTest().steal_suite());
    engine.add_suite(new Convey.App.ConversationTest().steal_suite());
    engine.add_suite(new Convey.App.ConversationSetTest().steal_suite());
    // Depends on ConversationTest and ConversationSetTest passing
    engine.add_suite(new Convey.App.ConversationMonitorTest().steal_suite());
    engine.add_suite(new Convey.Ascii.Test().steal_suite());
    engine.add_suite(new Convey.ConfigFileTest().steal_suite());
    engine.add_suite(new Convey.Db.DatabaseTest().steal_suite());
    engine.add_suite(new Convey.Db.VersionedDatabaseTest().steal_suite());
    engine.add_suite(new Convey.HTML.UtilTest().steal_suite());

    // Other IMAP tests rely on these working, so test them first
    engine.add_suite(new Convey.Imap.DataFormatTest().steal_suite());

    engine.add_suite(new Convey.Imap.CreateCommandTest().steal_suite());
    engine.add_suite(new Convey.Imap.RenameCommandTest().steal_suite());
    engine.add_suite(new Convey.Imap.FetchCommandTest().steal_suite());
    engine.add_suite(new Convey.Imap.FetchDataDecoderTest().steal_suite());
    engine.add_suite(new Convey.Imap.ListParameterTest().steal_suite());
    engine.add_suite(new Convey.Imap.MailboxSpecifierTest().steal_suite());
    engine.add_suite(new Convey.Imap.NamespaceResponseTest().steal_suite());

    // Depends on IMAP commands working
    engine.add_suite(new Convey.Imap.DeserializerTest().steal_suite());
    engine.add_suite(new Convey.Imap.ClientConnectionTest().steal_suite());
    engine.add_suite(new Convey.Imap.ClientSessionTest().steal_suite());

    engine.add_suite(new Convey.ImapDB.AccountTest().steal_suite());
    engine.add_suite(new Convey.ImapDB.AttachmentTest().steal_suite());
    engine.add_suite(new Convey.ImapDB.AttachmentIoTest().steal_suite());
    engine.add_suite(new Convey.ImapDB.DatabaseTest().steal_suite());
    engine.add_suite(new Convey.ImapDB.EmailIdentifierTest().steal_suite());
    engine.add_suite(new Convey.ImapDB.FolderTest().steal_suite());

    // Depends on ImapDB working
    engine.add_suite(new Convey.FtsSearchQueryTest().steal_suite());

    engine.add_suite(new Convey.ImapEngine.AccountProcessorTest().steal_suite());
    engine.add_suite(new Convey.ImapEngine.GenericAccountTest().steal_suite());

    // Depends on ImapDb.Database working correctly
    engine.add_suite(new Convey.ContactStoreImplTest().steal_suite());

    engine.add_suite(new Convey.Inet.Test().steal_suite());
    engine.add_suite(new Convey.Mime.ContentTypeTest().steal_suite());
    engine.add_suite(new Convey.Outbox.EmailIdentifierTest().steal_suite());
    engine.add_suite(new Convey.RFC822.MailboxAddressTest().steal_suite());
    engine.add_suite(new Convey.RFC822.MailboxAddressesTest().steal_suite());
    engine.add_suite(new Convey.RFC822.MessageDataTest().steal_suite());
    engine.add_suite(new Convey.RFC822.PartTest().steal_suite());
    engine.add_suite(new Convey.RFC822.Utils.Test().steal_suite());
    // Message requires all of the rest of the package working, so put
    // last
    engine.add_suite(new Convey.RFC822.MessageTest().steal_suite());
    engine.add_suite(new Convey.String.Test().steal_suite());
    engine.add_suite(new Convey.EmailTest().steal_suite());
    engine.add_suite(new Convey.ComposedEmailTest().steal_suite());

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
