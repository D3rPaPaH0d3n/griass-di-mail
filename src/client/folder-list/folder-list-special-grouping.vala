/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

// An ordered grouping meant to go alongside special folders in the account
// branch.
public class FolderList.SpecialGrouping : Sidebar.Grouping {
    // Must be != 0 and unique among SpecialGroupings.  Bigger comes later
    // in the list.  If < 0, it comes before non-SpecialGroupings.
    public int position { get; private set; }

    public SpecialGrouping(int position, string name, string? icon,
        string? tooltip = null) {
        base(name, icon, tooltip);

        this.position = position;
    }
}
