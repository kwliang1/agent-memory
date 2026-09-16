---
name: Keep controllers lean — business logic belongs in services
description: USVC controllers stay thin; domain logic (lookups, predicates, decisions) goes in a namespaced service object, not in private controller methods
type: feedback
originSessionId: 9abbb529-43ea-4f4d-9169-169c49af5611
---
Any business logic should live in a service object, not in the controller. Controllers should orchestrate (params → service call → render/redirect) and stay lean.

**Why:** Kevin called this out when reviewing a USVC-735 plan that put a "find newest commitment with open KYC" lookup as a private controller method. The codebase convention (AGENTS.md) is that domain logic lives in `app/services/<domain>/<name>_service.rb` (e.g. `Identity::CreateService`, `Payments::Crypto::WalletAddressService`) — class methods returning models or raising exceptions. Inline private controller helpers for domain decisions break that pattern, are harder to unit-test, and make controllers hard to read.

**How to apply:**
- When a controller change introduces a non-trivial predicate, lookup, or decision (anything beyond `params.permit` + `Model.find` + render/redirect), put it in a service under `app/services/<domain>/`.
- Existing inline helpers like `pending_kyc_commitment` in `InvestsController` are not a pattern to copy — they predate this preference. Prefer a new service object.
- Service objects: class method, descriptive name, returns a model or raises. Mirror the namespacing of nearby services in the same domain (e.g. `Identity::OpenKycRequirementsService`, not a generic `KycService`).
- Test the service in `spec/services/<domain>/` and keep the controller spec focused on routing/redirect behavior with the service stubbed.
