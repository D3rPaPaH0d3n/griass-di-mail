/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

public delegate uint Convey.State.Transition(uint state, uint event, void *user = null,
    Object? object = null, Error? err = null);

public delegate void Convey.State.PostTransition(void *user = null, Object? object = null,
    Error? err = null);

public class Convey.State.Mapping : BaseObject {
    public uint state;
    public uint event;
    public unowned Transition transition;

    public Mapping(uint state, uint event, Transition transition) {
        this.state = state;
        this.event = event;
        this.transition = transition;
    }
}

namespace Convey.State {

// A utility Transition for nop transitions (i.e. it merely returns the state passed in).
public uint nop(uint state, uint event) {
    return state;
}

}
