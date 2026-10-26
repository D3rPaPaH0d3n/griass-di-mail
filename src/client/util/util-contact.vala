/*
 * Copyright 2022 Cédric Bellegarde <cedric.bellegarde@adishatz.org>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

namespace Util.Contact {

    /**
     * Returns true if loading images for contact is allowed
     */
    public bool should_load_images(Application.Contact contact, Application.Configuration config) {
        var email_addresses = contact.email_addresses;
        var domains = config.get_images_trusted_domains();
        if (contact == null) {
            return false;
        // Contact trusted
        } else if (contact.load_remote_resources) {
            return true;
        // All emails are trusted
        } else if (domains.length > 0 && domains[0] == "*") {
            return true;
        // Contact domain trusted
        } else {
            for (uint i = 0; i < email_addresses.get_n_items(); i++) {
                var email = (Convey.RFC822.MailboxAddress) email_addresses.get_item(i);
                if (email.domain in domains) {
                    return true;
                }
            }
        }
        return false;
    }
}
