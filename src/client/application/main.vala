/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

int main(string[] args) {
    // Init logging right up front so as to capture as many log
    // messages as possible
    Convey.Logging.init();
    GLib.Log.set_writer_func(Convey.Logging.default_log_writer);

    Application.Client app = new Application.Client();

    int ec = app.run(args);

#if REF_TRACKING
    Convey.BaseObject.dump_refs(stdout);
#endif

    return ec;
}
