/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2019 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * Denotes an object with the standard set of RFC822 headers.
 */
public interface GriabuntuMail.EmailHeaderSet : BaseObject {

    /** Value of the RFC 822 From header, an originator field. */
    public abstract RFC822.MailboxAddresses? from { get; }

    /** Value of the RFC 822 Sender header, an originator field. */
    public abstract RFC822.MailboxAddress? sender { get; }

    /** Value of the RFC 822 Reply-To header, an originator field. */
    public abstract RFC822.MailboxAddresses? reply_to { get; }

    /** Value of the RFC 822 To header, a recipient field. */
    public abstract RFC822.MailboxAddresses? to { get; }

    /** Value of the RFC 822 Cc header, a recipient field. */
    public abstract RFC822.MailboxAddresses? cc { get; }

    /** Value of the RFC 822 Bcc header, a recipient field. */
    public abstract RFC822.MailboxAddresses? bcc { get; }

    /** Value of the RFC 822 Message-Id header, a reference field. */
    public abstract RFC822.MessageID? message_id { get; }

    /** Value of the RFC 822 In-Reply-To header, a reference field. */
    public abstract RFC822.MessageIDList? in_reply_to { get; }

    /** Value of the RFC 822 References header, a reference field. */
    public abstract RFC822.MessageIDList? references { get; }

    /** Value of the RFC 822 Subject header. */
    public abstract RFC822.Subject? subject { get; }

    /** Value of the RFC 822 Date header. */
    public abstract RFC822.Date? date { get; }

}
