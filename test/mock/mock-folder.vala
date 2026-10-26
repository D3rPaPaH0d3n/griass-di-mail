/*
 * Copyright 2017 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

public class Mock.Folder : Convey.Folder,
    ValaUnit.TestAssertions,
    ValaUnit.MockObject {


    public override Convey.Account account {
        get { return this._account; }
    }

    public override Convey.FolderProperties properties {
        get { return this._properties; }
    }

    public override Convey.FolderPath path {
        get { return this._path; }
    }

    public override Convey.Folder.SpecialUse used_as {
        get { return this._used_as; }
    }

    public override Convey.ProgressMonitor opening_monitor {
        get { return this._opening_monitor; }
    }

    protected Gee.Queue<ValaUnit.ExpectedCall> expected {
        get; set; default = new Gee.LinkedList<ValaUnit.ExpectedCall>();
    }


    private Convey.Account _account;
    private Convey.FolderProperties _properties;
    private Convey.FolderPath _path;
    private Convey.Folder.SpecialUse _used_as;
    private Convey.ProgressMonitor _opening_monitor;


    public Folder(Convey.Account? account,
                  Convey.FolderProperties? properties,
                  Convey.FolderPath? path,
                  Convey.Folder.SpecialUse used_as,
                  Convey.ProgressMonitor? monitor) {
        this._account = account;
        this._properties = properties ?? new FolderPoperties();
        this._path = path;
        this._used_as = used_as;
        this._opening_monitor = monitor;
    }

    public override Convey.Folder.OpenState get_open_state() {
        return Convey.Folder.OpenState.CLOSED;
    }

    public override async bool open_async(Convey.Folder.OpenFlags open_flags,
                                          GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        return yield boolean_call_async(
            "open_async",
            { int_arg(open_flags), cancellable },
            false
        );
    }

    public override async bool close_async(GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        return yield boolean_call_async(
            "close_async", { cancellable }, false
        );
    }

    public override async void wait_for_close_async(GLib.Cancellable? cancellable = null)
    throws GLib.Error {
        throw new Convey.EngineError.UNSUPPORTED("Mock method");
    }

    public override async void synchronise_remote(GLib.Cancellable? cancellable)
        throws GLib.Error {
        void_call("synchronise_remote", { cancellable });
    }

    public override async Gee.Collection<Convey.EmailIdentifier> contains_identifiers(
        Gee.Collection<Convey.EmailIdentifier> ids,
        GLib.Cancellable? cancellable = null)
    throws GLib.Error {
        return yield object_call_async<Gee.Collection<Convey.EmailIdentifier>>(
            "contains_identifiers",
            {ids, cancellable},
            new Gee.LinkedList<Convey.EmailIdentifier>()
        );
    }

    public override async Gee.List<Convey.Email>?
        list_email_by_id_async(Convey.EmailIdentifier? initial_id,
                               int count,
                               Convey.Email.Field required_fields,
                               Convey.Folder.ListFlags flags,
                               GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        return yield object_call_async<Gee.List<Convey.Email>?>(
            "list_email_by_id_async",
            {initial_id, int_arg(count), box_arg(required_fields), box_arg(flags), cancellable},
            null
        );
    }

    public override async Gee.List<Convey.Email>?
        list_email_by_sparse_id_async(Gee.Collection<Convey.EmailIdentifier> ids,
                                      Convey.Email.Field required_fields,
                                      Convey.Folder.ListFlags flags,
                                      GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        return yield object_call_async<Gee.List<Convey.Email>?>(
            "list_email_by_sparse_id_async",
            {ids, box_arg(required_fields), box_arg(flags), cancellable},
            null
        );
    }

    public override async Convey.Email
        fetch_email_async(Convey.EmailIdentifier email_id,
                          Convey.Email.Field required_fields,
                          Convey.Folder.ListFlags flags,
                          GLib.Cancellable? cancellable = null)
    throws GLib.Error {
        throw new Convey.EngineError.UNSUPPORTED("Mock method");
    }

    public override void set_used_as_custom(bool enabled)
        throws Convey.EngineError.UNSUPPORTED {
        throw new Convey.EngineError.UNSUPPORTED("Mock method");
    }

}
