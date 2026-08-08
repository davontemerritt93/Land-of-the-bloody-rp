# LAND OF THE BLOODY RP — Core Build v0.3
## Serious RP | **The city remembers.**

This repository is the custom gameplay layer for **Land of the Bloody RP**, built for a current Qbox server.

LOTB is designed around persistent consequences instead of disconnected minigames. The city remembers characters, neighborhoods change, witnesses lose confidence over time, important objects gain history, contacts remember relationships, investigations persist, businesses hold real stock, and a hidden opportunity director reacts to the state of the city.

## Working custom resources

- `lotb_core` — security helpers, audit logging, `/lotbhealth` runtime check.
- `lotb_identity` — `/rpstory` character history and long-term goals stored in Qbox metadata.
- `lotb_citymemory` — hidden character memory plus neighborhood trust/pressure/prosperity/instability/community-pride.
- `lotb_scenethreads` — persistent investigations, disputes, contracts, stories and unresolved RP threads.
- `lotb_evidence` — evidence provenance, integrity, case assignment and chain-of-custody.
- `lotb_economy` — audited server-authoritative player bank transfers.
- `lotb_businesses` — persistent ownership, reputation and physical supply stock.
- `lotb_crews` — hidden crew heat/influence without an arcade territory map.
- `lotb_contracts` — persistent agreements with optional bank-funded escrow.
- `lotb_dispatch` — server-authoritative 911/311 with responder alerts and waypoints.
- `lotb_justice` — cases, evidence lookup, warrants and precedent-ready case storage.
- `lotb_medical` — persistent EMS medical records and continuity.
- `lotb_world` — decaying witness memory, named contacts, and Object Legacy.
- `lotb_rumors` — imperfect information with confidence instead of omniscient alerts.
- `lotb_opportunities` — hidden City Director that generates local RP opportunities from district conditions.
- `lotb_hud` — custom black/blood-red HUD using Qbox PlayerData.

## Install

1. Deploy the current official Qbox txAdmin recipe and confirm it works before adding LOTB.
2. Import `sql/lotb.sql` into the same MariaDB database.
3. Copy `resources/[lotb]` into the server resources directory.
4. Add the LOTB ACE permissions and `ensure` block from `server.cfg.example` after Qbox/ox dependencies.
5. Restart and run `/lotbhealth` as an admin.
6. Follow `docs/INSTALL.md` for the full smoke-test sequence.

## What this repository intentionally does not include

This repo does not redistribute Qbox/ox resources, paid scripts, MLOs, copyrighted vehicle/clothing packs, phone assets, voice resources, or private credentials. Those belong in the actual server deployment and must be installed/licensed separately.

## LOTB design rule

**One good scene should be able to create days or weeks of RP.**

A shooting can affect a district, create witness reports, start an investigation thread, produce evidence, generate rumors, change crew heat, hurt a nearby business, become a court case, and eventually enter the city's history. That cross-system consequence is the identity of Land of the Bloody RP.
