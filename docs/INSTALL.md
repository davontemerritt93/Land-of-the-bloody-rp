# Land of the Bloody RP — Installation

## What this repository is

This repository is the custom **LOTB gameplay layer**. It expects a current Qbox server underneath it; it does not vendor Qbox, ox_lib, oxmysql, inventory, voice, appearance, phone, maps, vehicles, or paid assets.

## Required base

Use the current official Qbox txAdmin recipe for the base server. LOTB expects at minimum:

- FiveM/FXServer with OneSync
- Qbox / qbx_core
- ox_lib
- oxmysql
- MariaDB supported by the current Qbox release

For a normal production city you will also want the Qbox recipe's inventory, appearance, voice, phone/communication choices, garages, spawn/character resources, and other base resources you select.

## Install LOTB

1. Deploy and boot a clean Qbox server first.
2. Confirm you can create/log into a character and Qbox has no console errors.
3. Back up the database.
4. Import `sql/lotb.sql` into the same MariaDB database used by Qbox.
5. Copy `resources/[lotb]` into the server's `resources` directory.
6. Copy the LOTB ACE permissions and `ensure` block from `server.cfg.example` into your real configuration after Qbox/ox dependencies.
7. Map your real administrator principals to `group.admin` or the LOTB ACE permissions in your private permissions config.
8. Restart the server.
9. As an admin, run `/lotbhealth`.

## Expected `/lotbhealth` result

`LOTB health: database ready and all custom resources started.`

If it reports a missing resource, check that exact folder name and its startup console error. If it reports the schema missing, verify the connection string and import `sql/lotb.sql` again.

## First smoke test

Use a real test character and run:

- `/rpstory` — saves character story/goals.
- `/mymemory` — displays qualitative character memory.
- `/citypulse` — describes the current district without exposing raw hidden scores.
- `/rumors` — opens the rumor network.
- `/leads` — shows local dynamically generated RP opportunities.
- `/contacts` — shows named contacts the character has actually interacted with.
- `/objecthistory <key>` — reads registered object history.
- `/911` and `/311` — creates server-authoritative dispatch calls.
- `/paybank` — audited player-to-player bank transfer.
- `/contract` — creates an RP contract with optional escrow.
- `/business` — shows businesses owned by the character.
- `/crew` — shows qualitative crew heat/influence.
- `/hud` — toggles the LOTB HUD.

Police/DOJ smoke tests:

- `/casecreate <title>`
- `/caseview <case-key>`
- `/warrantissue <player-id> <case-key> <reason>`
- `/warrants <player-id>`
- `/evidencecreate <type> [case-key] [note]`
- `/evidence <evidence-key>`
- `/witnesscreate <event-type> <confidence> <case-key-or-none> <description>`
- `/witnesses [case-key]`

EMS smoke tests:

- `/medicaladd <player-id> <type> <summary>`
- `/medical <player-id>`

Admin setup tests:

- `/businesscreate <player-id> <business-key> <district> <name>`
- `/crewcreate <leader-id> <crew-key> <name>`
- `/crewadd <crew-key> <player-id> <rank>`
- `/lotbmemoryadd <player-id> <memory-type> <weight>`
- `/lotbdistrict <district> <field> <amount>`
- `/contactstanding <player-id> <contact-key> <trust> <fear> <debt>`
- `/legacycreate <type> <key> <label>`
- `/legacyadd <key> <event-type> <importance> <summary>`
- `/lotbgenerate [district]`

## Important production notes

- Never commit Cfx license keys, database passwords, Discord tokens, phone API credentials, webhooks, or paid asset files to this public repository.
- Use a staging server before production updates.
- Do not trust clients with money, inventory, evidence, reputation, district state, or rewards. LOTB's sensitive mutations are server-side for this reason.
- Back up MariaDB before schema changes.
- This code is a custom gameplay foundation; custom MLOs, vehicles, clothing, phone assets, audio, and other art/content still need to be licensed/installed separately.
