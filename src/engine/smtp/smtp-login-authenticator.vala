/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * SASL's LOGIN authentication schema implemented as an {@link Authenticator}.
 *
 * LOGIN is obsolete but still widely in use and provided for backward compatibility.
 *
 * See [[https://tools.ietf.org/html/draft-murchison-sasl-login-00]]
 */

public class GriabuntuMail.Smtp.LoginAuthenticator : GriabuntuMail.Smtp.Authenticator {
    public LoginAuthenticator(Credentials credentials) {
        base ("LOGIN", credentials);
    }

    public override Request initiate() {
        return new Request(Command.AUTH, { "login" });
    }

    public override Memory.Buffer? challenge(int step, Response response) throws SmtpError {
        switch (step) {
            case 0:
                return new Memory.StringBuffer(Base64.encode(credentials.user.data));

            case 1:
                return new Memory.StringBuffer(Base64.encode((credentials.token ?? "").data));

            default:
                return null;
        }
    }
}

