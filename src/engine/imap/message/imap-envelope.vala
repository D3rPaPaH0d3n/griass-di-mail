/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * A representation of the IMAP ENVELOPE data.
 *
 * See [[http://tools.ietf.org/html/rfc3501#section-7.4.2]]
 */

public class GriabuntuMail.Imap.Envelope : GriabuntuMail.MessageData.AbstractMessageData, GriabuntuMail.Imap.MessageData {
    public GriabuntuMail.RFC822.Date? sent { get; private set; }
    public GriabuntuMail.RFC822.Subject subject { get; private set; }
    public GriabuntuMail.RFC822.MailboxAddresses from { get; private set; }
    public GriabuntuMail.RFC822.MailboxAddresses sender { get; private set; }
    public GriabuntuMail.RFC822.MailboxAddresses reply_to { get; private set; }
    public GriabuntuMail.RFC822.MailboxAddresses? to { get; private set; }
    public GriabuntuMail.RFC822.MailboxAddresses? cc { get; private set; }
    public GriabuntuMail.RFC822.MailboxAddresses? bcc { get; private set; }
    public GriabuntuMail.RFC822.MessageIDList? in_reply_to { get; private set; }
    public GriabuntuMail.RFC822.MessageID? message_id { get; private set; }

    public Envelope(GriabuntuMail.RFC822.Date? sent, GriabuntuMail.RFC822.Subject subject,
        GriabuntuMail.RFC822.MailboxAddresses from, GriabuntuMail.RFC822.MailboxAddresses sender,
        GriabuntuMail.RFC822.MailboxAddresses reply_to, GriabuntuMail.RFC822.MailboxAddresses? to,
        GriabuntuMail.RFC822.MailboxAddresses? cc, GriabuntuMail.RFC822.MailboxAddresses? bcc,
        GriabuntuMail.RFC822.MessageIDList? in_reply_to, GriabuntuMail.RFC822.MessageID? message_id) {
        this.sent = sent;
        this.subject = subject;
        this.from = from;
        this.sender = sender;
        this.reply_to = reply_to;
        this.to = to;
        this.cc = cc;
        this.bcc = bcc;
        this.in_reply_to = in_reply_to;
        this.message_id = message_id;
    }

    public override string to_string() {
        return "[%s] %s: \"%s\"".printf((sent != null) ? sent.to_string() : "(no date)",
            from.to_string(), subject.to_string());
    }
}
