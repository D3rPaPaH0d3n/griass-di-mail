/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * Allows for a common string to be represented as an {@link Memory.Buffer}.
 */

public class Convey.Memory.StringBuffer : Memory.Buffer, Memory.UnownedStringBuffer,
    Memory.UnownedBytesBuffer {
    public override size_t size {
        get {
            return length;
        }
    }

    public override size_t allocated_size {
        get {
            return length;
        }
    }

    private string str;
    private size_t length;
    private Bytes? bytes = null;

    public StringBuffer(string str) {
        this.str = str;
        length = str.data.length;
    }

    /**
     * {@inheritDoc}
     */
    public override Bytes get_bytes() {
        return (bytes != null) ? bytes : bytes = new Bytes(str.data);
    }

    /**
     * {@inheritDoc}
     */
    public override string to_string() {
        return str;
    }

    /**
     * {@inheritDoc}
     */
    public override string get_valid_utf8() {
        return str.validate() ? str : "";
    }

    /**
     * {@inheritDoc}
     */
    public unowned string to_unowned_string() {
        return str;
    }

    /**
     * {@inheritDoc}
     */
    public unowned uint8[] to_unowned_uint8_array() {
        return str.data;
    }
}

