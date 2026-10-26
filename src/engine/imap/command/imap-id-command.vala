/*
 * Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * See [[http://www.ietf.org/rfc/rfc2971.txt]]
 */
public class Convey.Imap.IdCommand : Command {

    public const string NAME = "id";

    public IdCommand(Gee.HashMap<string, string> fields,
                     GLib.Cancellable? should_send) {
        base(NAME, null, should_send);

        ListParameter list = new ListParameter();
        foreach (string key in fields.keys) {
            list.add(new QuotedStringParameter(key));
            list.add(new QuotedStringParameter(fields.get(key)));
        }

        this.args.add(list);
    }

    public IdCommand.nil(GLib.Cancellable? should_send) {
        base(NAME, null, should_send);
        this.args.add(NilParameter.instance);
    }

}
