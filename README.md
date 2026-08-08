# LAND OF THE BLOODY RP — Core Build v0.2
## Serious RP | "The city remembers."

This package upgrades the original LOTB foundation into a working custom-resource layer for Qbox.

### Fast start
1. Deploy a clean Qbox server with txAdmin.
2. Confirm `qbx_core`, `ox_lib`, `oxmysql`, and your normal inventory/voice/appearance stack work.
3. Import `sql/lotb.sql` into the same database.
4. Copy `resources/[lotb]` into your server resources folder.
5. Add the LOTB `ensure` block from `server.cfg.example` after dependencies.
6. Give your admin principal the supplied ACE permissions.
7. Restart and use `/rpstory`, `/hud`, `/911`, `/paybank` for smoke tests.

### The architecture
LOTB does **not** replace Qbox money/character ownership. It adds persistent roleplay history and server-authoritative systems above it.

The key difference is cross-system consequence:
- A violent scene can alter district pressure.
- An investigation persists as a scene thread.
- Evidence has custody history.
- Businesses can react to neighborhood prosperity.
- Crews carry hidden heat/influence instead of an arcade territory score.
- Contracts and court cases remain part of a character's continuing story.

Read `docs/CORE_BUILD_V02.md` and `docs/UNIQUE_SYSTEMS_NEXT.md` before adding third-party scripts.
