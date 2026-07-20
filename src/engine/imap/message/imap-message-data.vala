/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

/**
 * MessageData is an IMAP data structure delivered in some form by the server to the client.
 *
 * Note that IMAP specifies that Flags and Attributes are *always* returned as a list, even if only
 * one is present, which is why these elements are MessageData but not the elements within the
 * lists (Flag, Attribute).
 *
 * Also note that Imap.MessageData requires {@link Convey.MessageData.AbstractMessageData}.
 *
 * TODO: Add an abstract to_parameter() method that can be used to serialize the message data.
 */

public interface Convey.Imap.MessageData : Convey.MessageData.AbstractMessageData {
}

public class Convey.Imap.RFC822Size : Convey.MessageData.Int64MessageData, Convey.Imap.MessageData {
    public RFC822Size(int64 value) {
        base (value);
    }
}

public class Convey.Imap.RFC822Header : Convey.RFC822.Header, Convey.Imap.MessageData {
    public RFC822Header(Memory.Buffer buffer)
        throws ImapError {
        try {
            base(buffer);
        } catch (RFC822.Error error) {
            throw new ImapError.INVALID(error.message);
        }
    }
}

public class Convey.Imap.RFC822Text : Convey.RFC822.Text, Convey.Imap.MessageData {
    public RFC822Text(Memory.Buffer buffer) {
        base (buffer);
    }
}

public class Convey.Imap.RFC822Full : Convey.RFC822.Full, Convey.Imap.MessageData {
    public RFC822Full(Memory.Buffer buffer) {
        base (buffer);
    }
}
