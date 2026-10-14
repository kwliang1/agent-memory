---
name: bank1634-bny-cert-rotation
description: BANK-1634 install new BNY prod mTLS cert — BLOCKED on cert↔key mismatch (BNY re-keyed / need new private key)
metadata: 
  node_type: memory
  type: project
  originSessionId: 8b6a7d73-411f-4851-804f-62d7a07c6fcf
  modified: 2026-07-28T05:40:03.900Z
---

BANK-1634 "Install new BNY Production Certificate" — rotate our BNY prod mTLS **client** cert. Assigned Kevin, created by Bisher Anadani. Timeline: BNY swaps on their side **Aug 7 2026 (8–11pm EST)**, old cert expires **Aug 14 2026**, ticket due **Aug 5 2026**. Kevin confirmed **prod only**.

**What/where:** cert = env var `BNY_ANGELLIST_PROD_CERTIFICATE` (holds base64 of PEM), paired key = `BNY_ANGELLIST_PROD_PRIVATE_KEY_PEM`. Both stored **encrypted in-repo** via configtool `encrypted|…` blobs in `config/configtool/prod-us-west-2-zeus/config.yaml` (lines ~34-35). Consumed at `backend/dibs/app/services/dibs/integrations/bny/api_service.rb:89-90` as `ssl_client_cert`/`ssl_client_key`. NOT a plaintext repo file. QA uses different vars (`BNY_ANGELLIST_CERTIFICATE`/`_PRIVATE_KEY_PEM`).

**Install mechanism (local-runnable, no KMS):** `al config set --config <path> <KEY> <base64val> --secret` encrypts with the env's in-repo **public** key (decrypt needs KMS, encrypt doesn't). Then `al config validate`. Precedent = PR **#8252** (JPM mTLS certs, merged Jul 2025), one-file change, prod-us-west-2-zeus only. Original BNY install = Taylor's PR #5703 + #6068 (2025); **first-ever BNY cert rotation** (value never changed since).

**PKI model = CSR-we-own** (per BANK-430 + BANK-491): AngelList generates keypair + CSR (`openssl genrsa`/`req`), BNY signs and returns the cert; **private key never leaves us**. So BNY can't unilaterally re-key.

**⚠️ BLOCKER — cert↔key mismatch (verified):**
- new cert pubkey SHA256(DER) = `6b5f42965df8053fe07a0c6b4e862f29058603ae5b5164418d2103225a018f40`
- current deployed prod key pubkey SHA256(DER) = `4e5060bd3ee16f65c3f7c6c5803426814f42fe44f98e267d7522c7d5cb811bb0`
- They DIFFER → cert-only swap breaks BNY prod mTLS handshake. Need the **matching new private key**, which BNY did NOT attach (`.cer` is public only).
- Verify a candidate key in read console: `Digest::SHA256.hexdigest(OpenSSL::PKey::RSA.new(Base64.decode64(pem)).public_key.to_der)` must equal `6b5f4296…8f40`.

**Exhausted repo + Slack + 1Password** for the matching key: nothing. Only a **JPM** mTLS 1Password item exists (search "mtls"); no BNY CSR/key anywhere. So a renewal CSR/key was either generated off-channel or BNY issued differently this time.

**Awaiting Bisher/Taylor** on the CSR-origin question (message drafted in thread): (1) did we send BNY a new CSR + where's the key, or does BNY owe us the key; (2) if regenerating, what CSR subject/SAN BNY expects (issued cert CN=`bax.prod.bnymellon.net`, SAN also `bax.prod.bny.net`, valid Jun 26 2026→Jun 25 2028).

**Two resolution paths, ~5 min each:** (A) they produce matching key → ship cert+key in one prod configtool PR w/ fingerprint proof; (B) regenerate → I run `openssl genrsa`/`req`, hand off CSR, install pair when signed cert returns. New cert staged in session scratchpad (`bax.prod.bnymellon.net.cer`). No key material ever pasted to chat.

Related: [[bank1665-nova-fbo-prophet]] (other treasury-prism/DIBS work).

Superseded by [bank1634-bny-cert-is-servercert](bank1634-bny-cert-is-servercert.md).
