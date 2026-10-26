/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * Interface which allows access to backing string of {@link Memory.Buffer} without transferring
 * ownership, i.e. copying the string.
 *
 * The presence of this interface indicates that obtaining access to the backing string is cheap.
 *
 * Not all AbstractBuffers can support this call, but if they can, this interface allows for it.
 * The buffers that are returned should ''not'' be modified or freed by the caller.
 */

public interface Convey.Memory.UnownedStringBuffer : Memory.Buffer {
    /**
     * Returns an unowned string version of the backing buffer.
     *
     * The returned string should not be modified or freed.
     */
    public abstract unowned string to_unowned_string();

}
