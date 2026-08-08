# Land of the Bloody RP — Installation

## What this repository is

This repository is the custom **LOTB gameplay layer**. It expects a current Qbox server underneath it; it does not vendor Qbox, ox_lib, oxmysql, ox_inventory, qbx_vehicles, voice, appearance, phone, maps, vehicles, or paid assets.

## Required base

Use the current official Qbox txAdmin recipe for the base server. LOTB v0.4 expects at minimum:

- FiveM/FXServer with OneSync
- Qbox / `qbx_core`
- `ox_lib`
- `oxmysql`
- `ox_inventory`
- `qbx_vehicles`
- MariaDB supported by the current Qbox release

For a production city also install/configure garages, appearance, voice, phone/communications, spawn/character resources, maps/MLOs and your licensed content.

## Install LOTB

1. Deploy and boot a clean current Qbox server first.
2. Confirm you can create/log into a character and the base has no console errors.
3. Back up MariaDB.
4. Import `sql/lotb.sql`.
5. Import `sql/lotb_v04.sql` after the base LOTB schema.
6. Optional for quick dealership testing: import `sql/lotb_seed_v04.sql`.
7. Copy `resources/[lotb]` into the server `resources` directory.
8. Copy the LOTB ACE permissions and `ensure` block from `server.cfg.example` after Qbox/ox dependencies.
9. Map real staff principals to the LOTB ACE permissions in your private production config.
10. Restart.
11. Run `/lotbhealth` as an admin.

Expected result:

`LOTB v0.4 health: database ready and all custom resources started.`

## Player/civilian smoke tests

- `/rpstory` — character story/goals; new characters are prompted automatically after Qbox loads them.
- `/mymemory` — qualitative character memory.
- `/citypulse` — qualitative district condition.
- `/rumors` — rumor network.
- `/leads` — City Director opportunities.
- `/contacts` — named contacts.
- `/objecthistory <key>` — object legacy.
- `/archive` — public city history.
- `/911` and `/311` — dispatch.
- `/paybank` — audited personal transfer.
- `/contract` — contracts/escrow.
- `/business` — business state/stock.
- `/banking` — personal overview and owned business accounts.
- `/crew` — qualitative crew standing.
- `/will` — wills and beneficiaries.
- `/property` — nearby and owned/access-granted properties.
- `/civicwork` — neighborhood-driven legitimate public work.
- `/dealer [dealership-key]` — dealership stock.
- `/mycars` — registered Qbox vehicles.
- `/repairorder`, `/workorders`, `/servicehistory <vehicle-id>` — mechanic loop.
- `/underworld` — relationship-driven underworld progression.
- `/craftknowledge` — known recipes.
- `/robbery` — starts a qualified robbery scene when at a configured target.
- `/hud` — custom LOTB HUD.

## Department smoke tests

Police:
- `/mdt` — dispatch, warrants, cases, evidence and witness reports.
- Existing case/evidence/warrant commands remain available.

EMS:
- `/emstablet` — recent medical records and patient lookup.
- Existing `/medicaladd` and `/medical` commands remain available.

DOJ:
- `/doj` — case docket, warrants, evidence and contract disputes.

Staff:
- `/staffpanel` — audit trail, notes and logged warnings.
- `/lotbhealth` — runtime health check.
- `/createproperty` — create a property listing at current position.
- `/dealerstock` — add/update vehicle inventory.

## Underworld crafting items

The sample recipes in `sql/lotb_v04.sql` reference example item names. See `docs/UNDERWORLD_ITEMS.md` and map those recipes to the item definitions on your selected ox_inventory setup before public launch.

## Important production notes

- Never commit Cfx license keys, DB passwords, Discord tokens, phone credentials, webhooks, or paid assets.
- Use a staging server before production updates.
- LOTB keeps money, inventory, evidence, progression, property ownership and rewards server-authoritative.
- Qbox-owned vehicle data is accessed through Qbox vehicle exports; LOTB does not write directly to Qbox vehicle tables.
- Back up MariaDB before schema changes.
- Run actual exploit/performance/load tests on the FXServer before opening the whitelist.
- MLOs, clothing, vehicle packs, custom audio and other art/content still require separately licensed/created assets.
