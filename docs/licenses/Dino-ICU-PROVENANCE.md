# Dino-derived ICU binding

The local `bindings/vapi/icu-uc.vapi` explicitly records Dino origin.
It was added to the inherited upstream by Michael Gratton in commit
`2f81fdf146cad612f52b70a3745ba555653f57a9` (2021-01-18).

A verified Dino source snapshot immediately preceding that import is
`e4b2f0c04979bf3075e2545fa950af9b76787279`. Its `xmpp-vala/vapi/icu-uc.vapi` contains the matching ICU
character, error and binding declarations; `main/vapi/icu-uc.vapi` also
contains ICU declarations. The local file is a minimal adaptation, not
a byte-identical vendored copy, and the import did not record an exact
Dino source revision. That historical limitation is retained explicitly.

The snapshot's root LICENSE is GNU GPL version 3, preserved verbatim as
`Dino-GPL-3.0.txt`. The current application copy is GPL-3.0-only. No
alternative permissive grant is inferred for this binding. Original
Dino provenance and Michael Gratton's upstream contribution are retained.

Sources:
https://github.com/dino/dino/tree/e4b2f0c04979bf3075e2545fa950af9b76787279/xmpp-vala/vapi
https://github.com/dino/dino/blob/e4b2f0c04979bf3075e2545fa950af9b76787279/LICENSE

Dovecot's separate UTF-7 fragments retain their original copyright in
`src/engine/util/util-imap-utf7.vala`; the exact 2.1.15 MIT text is now
provided as `Dovecot-2.1.15-MIT.txt` without relying on the historical
comment about whether the fragment was substantial. Source:
https://github.com/dovecot/core/blob/2.1.15/COPYING.MIT
SHA-256: 52b8c95fabb19575281874b661ef7968ea47e8f5d74ba0dd40ce512e52b3fc97
