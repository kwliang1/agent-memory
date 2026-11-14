---
name: iva-retirement-design-2026-11
description: "Forward-only IVA retirement design (2026-11-02): CCA→IVA hops live in callers, not Transfers V2; nil IVA beats IVA=CCA"
metadata:
  type: project
---
Design doc: https://claude.ai/artifact/NcguqAmNQEvqh57dikso88 (thread C045AHA7WFQ p1789404026184089; INC-5837).

- The V2 `create_mirror_account_backing_transfer_chain_if_applicable!` leg is Mirror→CCA. Do NOT remove it; CCA payouts need it.
- CCA→IVA hops come from callers: venture closings `sign!` (state_service.rb:432-434, double call = INC-5837), cptr fund expenses (payment_service.rb:430-447), and treasury legacy OW auto-funding plus the IvcPull/IvcCascade OP plans. The IVC TransferService mints a random idempotency token, so repeat calls can't be deduped.
- IVA = CCA (Thibaut/Byte idea) double-counts the CCA in sub_accounts/balance_service.rb:22,54 and creates self-transfers. Nil IVA is the safe shape.
- DCRs aren't relevant (none creates or funds an IVA). The DCR reviewer's IVA↔CCA auto-approve goes dead.
- Open: legal two-account comment (IVC model :43-76), sweep of idle IVA balances, CCA/IVA owner_entity match.
