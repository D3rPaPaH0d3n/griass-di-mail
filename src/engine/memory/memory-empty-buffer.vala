/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * An EmptyBuffer fulfills the interface of {@link Buffer} for a zero-length block.
 *
 * Because all EmptyBuffers are the same and immutable, only a single may be used: {@link instance}.
 */

public class GriabuntuMail.Memory.EmptyBuffer : Memory.Buffer, Memory.UnownedStringBuffer,
    Memory.UnownedBytesBuffer, Memory.UnownedByteArrayBuffer {
    private static EmptyBuffer? _instance = null;
    public static EmptyBuffer instance {
        get {
            return (_instance != null) ? _instance : _instance = new EmptyBuffer();
        }
    }

    /**
     * {@inheritDoc}
     */
    public override size_t size {
        get {
            return 0;
        }
    }

    /**
     * {@inheritDoc}
     */
    public override size_t allocated_size {
        get {
            return 0;
        }
    }

    private Bytes bytes = new Bytes(new uint8[0]);
    private ByteArray byte_array = new ByteArray();

    private EmptyBuffer() {
    }

    /**
     * {@inheritDoc}
     */
    public override Bytes get_bytes() {
        return bytes;
    }

    /**
     * {@inheritDoc}
     */
    public unowned uint8[] to_unowned_uint8_array() {
        return bytes.get_data();
    }

    /**
     * {@inheritDoc}
     */
    public unowned string to_unowned_string() {
        return "";
    }

    /**
     * {@inheritDoc}
     */
    public unowned ByteArray to_unowned_byte_array() {
        return byte_array;
    }
}

