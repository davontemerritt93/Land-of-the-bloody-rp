# LAND OF THE BLOODY RP — Core Build v0.4
## Serious RP | **The city remembers.**

LOTB is a Qbox-based serious-roleplay gameplay layer built around persistent consequences rather than disconnected minigames.

## Signature systems

- **City Memory** — hidden contextual character history instead of public XP.
- **District Pulse** — trust, pressure, prosperity, instability and community pride respond to RP.
- **Witness Memory** — witness confidence decays instead of producing magical perfect identification.
- **Rumor Network** — characters hear imperfect information with varying credibility.
- **Object Legacy** — important vehicles/items can accumulate real player-created history.
- **Named Contacts** — contacts remember trust, fear and debt.
- **Scene Threads** — investigations, disputes and stories persist across restarts.
- **Evidence Provenance** — evidence has integrity and custody history.
- **World Scars + City Archive** — major RP can leave aftermath and become city history.
- **Opportunity Director** — neighborhood conditions generate different RP circumstances.

## v0.4 production expansion

- Automatic serious-RP story/goals onboarding after Qbox character load.
- Wills, beneficiaries and succession hooks.
- Persistent property ownership, access and maintenance.
- Neighborhood-driven civilian civic work.
- Dealership stock and purchases through `qbx_vehicles` ownership APIs.
- Mechanic work orders, quotes, payments and permanent vehicle service history.
- Relationship-driven underworld progression and server-authoritative crafting.
- Consequence-driven robbery scenes that create dispatch, witnesses, evidence, rumors and district pressure.
- Personal/business banking overview, business deposits/withdrawals/transfers and ledgers.
- Police MDT, EMS tablet and DOJ docket using LOTB records.
- Staff audit/notes/warning panel.
- Runtime `/lotbhealth` plus repository consistency checks.

## Install

1. Deploy a current Qbox server using the official txAdmin recipe.
2. Confirm `qbx_core`, `ox_lib`, `oxmysql`, `ox_inventory` and `qbx_vehicles` work.
3. Import `sql/lotb.sql`.
4. Import `sql/lotb_v04.sql`.
5. Optionally import `sql/lotb_seed_v04.sql` for starter dealership stock.
6. Copy `resources/[lotb]` into your server resources folder.
7. Add the LOTB `ensure` block from `server.cfg.example` after dependencies.
8. Restart and run `/lotbhealth` as an admin.

See `docs/INSTALL.md` for smoke tests and deployment details.

## Architecture rule

LOTB does **not** modify Qbox core tables/code when a supported Qbox export exists. Money, inventory, rewards, evidence, property ownership and progression are server-authoritative. The goal is to remain upgradeable and make one scene create more RP later instead of simply paying out and disappearing.

## Still requires the actual production host

This repository does not redistribute Qbox, paid/licensed phone resources, custom MLOs, clothing, vehicle packs or audio. Phone/voice vendor integration, custom interiors/art and real-player performance/exploit testing must be completed on the actual FXServer deployment.
