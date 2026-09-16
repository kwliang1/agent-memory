---
name: inc-5462-venture-still-collapses
description: "venture wire_manual.rb still collapses the beneficiary-bank ABA to the correspondent's — the surface the incident reporter actually saw, and the only one of the three still unfixed"
metadata:
  type: reference
---

An international wire through Piermont/PCBB has **two real ABAs** — the beneficiary bank's and the correspondent's. They must not be collapsed into one.

**venture still collapses them**, in `wire_manual.rb`. That is the surface the incident reporter saw, and it is the only one of the three still unfixed: treasury #8515 fixed the PDF, nova #9436 fixed its display (approved, not merged).

Full analysis is in the treasury scope: `inc-5462-piermont-intl-wire-routing.md`.
