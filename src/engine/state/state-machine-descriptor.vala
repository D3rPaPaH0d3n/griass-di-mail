/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

public delegate string GriabuntuMail.State.StateEventToString(uint state_or_event);

public class GriabuntuMail.State.MachineDescriptor : BaseObject {
    public string name { get; private set; }
    public uint start_state { get; private set; }
    public uint state_count { get; private set; }
    public uint event_count { get; private set; }

    private unowned StateEventToString? state_to_string;
    private unowned StateEventToString? event_to_string;

    public MachineDescriptor(string name, uint start_state, uint state_count, uint event_count,
        StateEventToString? state_to_string, StateEventToString? event_to_string) {
        this.name = name;
        this.start_state = start_state;
        this.state_count = state_count;
        this.event_count = event_count;
        this.state_to_string = state_to_string;
        this.event_to_string = event_to_string;

        // starting state should be valid
        assert(start_state < state_count);
    }

    public string get_state_string(uint state) {
        return (state_to_string != null) ? state_to_string(state) : "%s STATE %u".printf(name, state);
    }

    public string get_event_string(uint event) {
        return (event_to_string != null) ? event_to_string(event) : "%s EVENT %u".printf(name, event);
    }
}

