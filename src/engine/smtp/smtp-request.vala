/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

public class GriabuntuMail.Smtp.Request {
    public Command cmd { get; private set; }
    public string[]? args { get; private set; }

    public Request(Command cmd, string[]? args = null) {
        this.cmd = cmd;
        this.args = args;
    }

    public string serialize() {
        // fast-path
        if (args == null || args.length == 0)
            return cmd.serialize();

        StringBuilder builder = new StringBuilder();

        builder.append(cmd.serialize());

        foreach (string arg in args) {
            builder.append_c(' ');
            builder.append(arg);
        }

        return builder.str;
    }

    public string to_string() {
        return serialize();
    }
}

public class GriabuntuMail.Smtp.HeloRequest : GriabuntuMail.Smtp.Request {
    public HeloRequest(string domain) {
        base (Command.HELO, { domain });
    }

    public HeloRequest.for_local_address(InetAddress local_addr) {
        this ("[%s]".printf(local_addr.to_string()));
    }
}

public class GriabuntuMail.Smtp.EhloRequest : GriabuntuMail.Smtp.Request {
    public EhloRequest(string domain) {
        base (Command.EHLO, { domain });
    }

    public EhloRequest.for_local_address(InetAddress local_addr) {
        string prefix = (local_addr.family == SocketFamily.IPV6) ? "IPv6:" : "";
        this ("[%s%s]".printf(prefix, local_addr.to_string()));
    }
}

public class GriabuntuMail.Smtp.MailRequest : GriabuntuMail.Smtp.Request {
    public MailRequest(GriabuntuMail.RFC822.MailboxAddress reverse_path) {
        base (Command.MAIL, { "from:<%s>".printf(reverse_path.to_rfc822_address()) });
    }
}

public class GriabuntuMail.Smtp.RcptRequest : GriabuntuMail.Smtp.Request {
    public RcptRequest(GriabuntuMail.RFC822.MailboxAddress to) {
        base (Command.RCPT, { "to:<%s>".printf(to.to_rfc822_address()) });
    }
}
