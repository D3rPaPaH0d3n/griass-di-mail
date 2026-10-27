/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Downstream modification: 2026-10-26 — full participant identity formatting. */
/*
 * Copyright © 2022 John Renner <john@jrenner.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

internal class ConversationList.Participant : GriabuntuMail.BaseObject, Gee.Hashable<Participant> {
    private const string ME = "Me";
    public GriabuntuMail.RFC822.MailboxAddress address;

    public Participant(GriabuntuMail.RFC822.MailboxAddress address) {
        this.address = address;
    }

    public string get_full_markup(Gee.List<GriabuntuMail.RFC822.MailboxAddress> account_mailboxes) {
        return get_as_markup((address in account_mailboxes)
            ? "%s %s".printf(ME, address.to_address_display())
            : address.to_full_display());
    }

    public string get_short_markup(Gee.List<GriabuntuMail.RFC822.MailboxAddress> account_mailboxes) {
        // Keep actual addresses visible for every participant, including
        // multi-sender threads. GtkLabel handles visual ellipsizing.
        return get_full_markup(account_mailboxes);
    }

    private string get_as_markup(string participant) {
        string markup = GriabuntuMail.HTML.escape_markup(participant);

        if (this.address.is_spoofed()) {
            markup = "<s>%s</s>".printf(markup);
        }

        return markup;
    }

    public bool equal_to(Participant other) {
        return address.equal_to(other.address)
            && address.name == other.address.name;
    }

    public uint hash() {
        return address.hash();
    }
}
