/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * Convey offers a couple of places where the user may mark an object (email, contact)
 * with a named flag.  The presence of the flag indicates if the state is enabled/on
 * or disabled/off.
 */

public class Convey.NamedFlag : BaseObject, Gee.Hashable<Convey.NamedFlag> {
    public string name { get; private set; }

    public NamedFlag(string name) {
        this.name = name;
    }

    public bool equal_to(Convey.NamedFlag other) {
        if (this == other)
            return true;

        return name.down() == other.name.down();
    }

    public uint hash() {
        return name.down().hash();
    }

    public string serialise() {
        return name;
    }

    public string to_string() {
        return name;
    }
}
