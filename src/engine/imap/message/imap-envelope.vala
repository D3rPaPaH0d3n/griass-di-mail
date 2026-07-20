/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

/**
 * A representation of the IMAP ENVELOPE data.
 *
 * See [[http://tools.ietf.org/html/rfc3501#section-7.4.2]]
 */

public class Convey.Imap.Envelope : Convey.MessageData.AbstractMessageData, Convey.Imap.MessageData {
    public Convey.RFC822.Date? sent { get; private set; }
    public Convey.RFC822.Subject subject { get; private set; }
    public Convey.RFC822.MailboxAddresses from { get; private set; }
    public Convey.RFC822.MailboxAddresses sender { get; private set; }
    public Convey.RFC822.MailboxAddresses reply_to { get; private set; }
    public Convey.RFC822.MailboxAddresses? to { get; private set; }
    public Convey.RFC822.MailboxAddresses? cc { get; private set; }
    public Convey.RFC822.MailboxAddresses? bcc { get; private set; }
    public Convey.RFC822.MessageIDList? in_reply_to { get; private set; }
    public Convey.RFC822.MessageID? message_id { get; private set; }

    public Envelope(Convey.RFC822.Date? sent, Convey.RFC822.Subject subject,
        Convey.RFC822.MailboxAddresses from, Convey.RFC822.MailboxAddresses sender,
        Convey.RFC822.MailboxAddresses reply_to, Convey.RFC822.MailboxAddresses? to,
        Convey.RFC822.MailboxAddresses? cc, Convey.RFC822.MailboxAddresses? bcc,
        Convey.RFC822.MessageIDList? in_reply_to, Convey.RFC822.MessageID? message_id) {
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
