/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * SASL's PLAIN authentication schema implemented as an {@link Authenticator}.
 *
 * See [[http://tools.ietf.org/html/rfc4616]]
 */

public class GriabuntuMail.Smtp.PlainAuthenticator : GriabuntuMail.Smtp.Authenticator {
    private static uint8[] nul = { '\0' };

    public PlainAuthenticator(Credentials credentials) {
        base ("PLAIN", credentials);
    }

    public override Request initiate() {
        return new Request(Command.AUTH, { "PLAIN" });
    }

    public override Memory.Buffer? challenge(int step, Response response) throws SmtpError {
        // only a single challenge is issued in PLAIN
        if (step > 0)
            return null;

        Memory.GrowableBuffer growable = new Memory.GrowableBuffer();
        // skip the "authorize" field, which we don't support
        growable.append(nul);
        growable.append(credentials.user.data);
        growable.append(nul);
        growable.append((credentials.token ?? "").data);

        // convert to Base64
        return new Memory.StringBuffer(Base64.encode(growable.get_bytes().get_data()));
    }
}

