/*
 * Copyright © 2016 Software Freedom Conservancy Inc.
 * Copyright © 2020 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * A connection to the database for transactions.
 */
internal class Convey.Db.TransactionConnection : BaseObject, Connection {


    /** {@inheritDoc} */
    public Database database { get { return this.db_cx.database; } }

    /** {@inheritDoc} */
    internal Sqlite.Database db { get { return this.db_cx.db; } }

    internal string[] transaction_log = {};

    private DatabaseConnection db_cx;


    internal TransactionConnection(DatabaseConnection db_cx) {
        this.db_cx = db_cx;
    }

    /** {@inheritDoc} */
    public Statement prepare(string sql) throws DatabaseError {
        this.transaction_log += sql;
        return this.db_cx.prepare(sql);
    }

    /** {@inheritDoc} */
    public Result query(string sql, GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        this.transaction_log += sql;
        return this.db_cx.query(sql, cancellable);
    }

    /** {@inheritDoc} */
    public void exec(string sql, GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        this.transaction_log += sql;
        this.db_cx.exec(sql, cancellable);
    }

    /** {@inheritDoc} */
    public void exec_file(GLib.File file, GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        this.transaction_log += file.get_uri();
        this.db_cx.exec_file(file, cancellable);
    }

}
