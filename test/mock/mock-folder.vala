/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2017 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

public class Mock.Folder : GriabuntuMail.Folder,
    ValaUnit.TestAssertions,
    ValaUnit.MockObject {


    public override GriabuntuMail.Account account {
        get { return this._account; }
    }

    public override GriabuntuMail.FolderProperties properties {
        get { return this._properties; }
    }

    public override GriabuntuMail.FolderPath path {
        get { return this._path; }
    }

    public override GriabuntuMail.Folder.SpecialUse used_as {
        get { return this._used_as; }
    }

    public override GriabuntuMail.ProgressMonitor opening_monitor {
        get { return this._opening_monitor; }
    }

    protected Gee.Queue<ValaUnit.ExpectedCall> expected {
        get; set; default = new Gee.LinkedList<ValaUnit.ExpectedCall>();
    }


    private GriabuntuMail.Account _account;
    private GriabuntuMail.FolderProperties _properties;
    private GriabuntuMail.FolderPath _path;
    private GriabuntuMail.Folder.SpecialUse _used_as;
    private GriabuntuMail.ProgressMonitor _opening_monitor;


    public Folder(GriabuntuMail.Account? account,
                  GriabuntuMail.FolderProperties? properties,
                  GriabuntuMail.FolderPath? path,
                  GriabuntuMail.Folder.SpecialUse used_as,
                  GriabuntuMail.ProgressMonitor? monitor) {
        this._account = account;
        this._properties = properties ?? new FolderPoperties();
        this._path = path;
        this._used_as = used_as;
        this._opening_monitor = monitor;
    }

    public override GriabuntuMail.Folder.OpenState get_open_state() {
        return GriabuntuMail.Folder.OpenState.CLOSED;
    }

    public override async bool open_async(GriabuntuMail.Folder.OpenFlags open_flags,
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
        throw new GriabuntuMail.EngineError.UNSUPPORTED("Mock method");
    }

    public override async void synchronise_remote(GLib.Cancellable? cancellable)
        throws GLib.Error {
        void_call("synchronise_remote", { cancellable });
    }

    public override async Gee.Collection<GriabuntuMail.EmailIdentifier> contains_identifiers(
        Gee.Collection<GriabuntuMail.EmailIdentifier> ids,
        GLib.Cancellable? cancellable = null)
    throws GLib.Error {
        return yield object_call_async<Gee.Collection<GriabuntuMail.EmailIdentifier>>(
            "contains_identifiers",
            {ids, cancellable},
            new Gee.LinkedList<GriabuntuMail.EmailIdentifier>()
        );
    }

    public override async Gee.List<GriabuntuMail.Email>?
        list_email_by_id_async(GriabuntuMail.EmailIdentifier? initial_id,
                               int count,
                               GriabuntuMail.Email.Field required_fields,
                               GriabuntuMail.Folder.ListFlags flags,
                               GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        return yield object_call_async<Gee.List<GriabuntuMail.Email>?>(
            "list_email_by_id_async",
            {initial_id, int_arg(count), box_arg(required_fields), box_arg(flags), cancellable},
            null
        );
    }

    public override async Gee.List<GriabuntuMail.Email>?
        list_email_by_sparse_id_async(Gee.Collection<GriabuntuMail.EmailIdentifier> ids,
                                      GriabuntuMail.Email.Field required_fields,
                                      GriabuntuMail.Folder.ListFlags flags,
                                      GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        return yield object_call_async<Gee.List<GriabuntuMail.Email>?>(
            "list_email_by_sparse_id_async",
            {ids, box_arg(required_fields), box_arg(flags), cancellable},
            null
        );
    }

    public override async GriabuntuMail.Email
        fetch_email_async(GriabuntuMail.EmailIdentifier email_id,
                          GriabuntuMail.Email.Field required_fields,
                          GriabuntuMail.Folder.ListFlags flags,
                          GLib.Cancellable? cancellable = null)
    throws GLib.Error {
        throw new GriabuntuMail.EngineError.UNSUPPORTED("Mock method");
    }

    public override void set_used_as_custom(bool enabled)
        throws GriabuntuMail.EngineError.UNSUPPORTED {
        throw new GriabuntuMail.EngineError.UNSUPPORTED("Mock method");
    }

}
