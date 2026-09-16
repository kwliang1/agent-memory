---
name: bank1634-bny-cert-is-servercert
description: "BANK-1634 \"install new BNY prod cert\" — the attached cert is BNY's OWN server cert, not ours; treasury doesn't pin it → likely no-op close-out."
metadata: 
  node_type: memory
  type: project
  originSessionId: 141987c6-028e-4303-925d-479aef1dfab9
  modified: 2026-07-31T21:02:53.631Z
---

BANK-1634 ("Install new BNY Production Certificate", assigned Kevin, created by Bisher) is almost certainly a **no-op on our side** — the ticket's framing is misleading.

**The attached cert (`bax.prod.bnymellon.net.cer`, key `6b5f4296…8f40`) is BNY's OWN prod SERVER cert**, not our client cert. Decoded: `O=The Bank of New York Mellon, OU=BAX, CN=bax.prod.bnymellon.net`, SAN also `bax.prod.bny.net`, EKU=TLS **Server** Auth, issuer=BNY Mellon Corporation Issuing CA 3 (private CA), validity Jun 26 2026→Jun 25 2028. BNY's note ("we'll replace the old cert in production Aug 7, expires Aug 14") describes a swap on *BNY's* side.

**Why it needs nothing from us (verified 3 ways):**
1. Our real client cert is `O=Angellist, CN=Angellist`, key `4e5060bd…1bb0`, **valid to 2027-07-14** (decoded original "Prod Signed Cert.pem" + prod console). Different party, healthy, untouched.
2. Treasury/DIBS connects to `apigateway.bnymellon.com` + `apigatewayb2b.bnymellon.com` (set in `backend/dibs/app/services/dibs/integrations/bny/api_service.rb` env_config `host`), NOT `bax.prod`. Live TLS probe: both gateways present **DigiCert** (public CA) server certs — that's why our `ssl_verify=true` with **no `ca_file`/`cert_store`** works (default trust bundle).
3. Whole-repo grep: we store/reference/pin no `bax.*`/BNY server cert anywhere. `BNY_PUBLIC_KEY_PEM` is defined but unused.

**Recommended close-out:** one line to Bisher — "This is BNY's server cert for the bax.prod endpoint; treasury uses apigateway.bnymellon.com (DigiCert) and doesn't pin BNY's cert, so no change needed. Does any other system connect to bax.prod directly?" If no → close. Honest boundary: verified for treasury only; can't rule out another system / planned BNY-BAX integration using bax.prod.

**Should we pin BNY's cert?** Separate security-team decision, NOT this ticket. Pro: MITM defense vs a mis-issued public CA. Con: every BNY/DigiCert rotation becomes a mandatory coordinated config update or payments break.

**Do NOT** generate a CSR / rotate our client cert for this ticket (an earlier session "pixel" misclassified the cert as ours and went down the CSR path — wrong). See also [[treasury-prod-console-access]].
