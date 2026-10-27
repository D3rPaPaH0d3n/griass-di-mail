/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * MessageData is an IMAP data structure delivered in some form by the server to the client.
 *
 * Note that IMAP specifies that Flags and Attributes are *always* returned as a list, even if only
 * one is present, which is why these elements are MessageData but not the elements within the
 * lists (Flag, Attribute).
 *
 * Also note that Imap.MessageData requires {@link GriabuntuMail.MessageData.AbstractMessageData}.
 *
 * TODO: Add an abstract to_parameter() method that can be used to serialize the message data.
 */

public interface GriabuntuMail.Imap.MessageData : GriabuntuMail.MessageData.AbstractMessageData {
}

public class GriabuntuMail.Imap.RFC822Size : GriabuntuMail.MessageData.Int64MessageData, GriabuntuMail.Imap.MessageData {
    public RFC822Size(int64 value) {
        base (value);
    }
}

public class GriabuntuMail.Imap.RFC822Header : GriabuntuMail.RFC822.Header, GriabuntuMail.Imap.MessageData {
    public RFC822Header(Memory.Buffer buffer)
        throws ImapError {
        try {
            base(buffer);
        } catch (RFC822.Error error) {
            throw new ImapError.INVALID(error.message);
        }
    }
}

public class GriabuntuMail.Imap.RFC822Text : GriabuntuMail.RFC822.Text, GriabuntuMail.Imap.MessageData {
    public RFC822Text(Memory.Buffer buffer) {
        base (buffer);
    }
}

public class GriabuntuMail.Imap.RFC822Full : GriabuntuMail.RFC822.Full, GriabuntuMail.Imap.MessageData {
    public RFC822Full(Memory.Buffer buffer) {
        base (buffer);
    }
}
