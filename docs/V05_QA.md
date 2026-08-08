# LOTB v0.5 Deployment QA

This checklist separates repository-level guarantees from tests that can only be performed on the actual FXServer.

## Repository checks

Before deployment:

1. Run `python tools/check_repo.py`.
2. Confirm `sql/lotb.sql`, `sql/lotb_v04.sql`, and `sql/lotb_v05.sql` are imported in that order.
3. Confirm `lotb_pending_payouts` exists after the v0.5 migration; mechanic earnings depend on it.
4. Confirm every `ensure lotb_*` in `server.cfg.example` has a matching resource folder and manifest.
5. Do not commit Cfx keys, database passwords, phone credentials, Discord tokens, webhooks, or paid assets.

## First-boot checks

After starting the staging server:

1. Run `/lotbhealth` as an administrator.
2. Create a fresh character and confirm serious-RP story/goals onboarding appears after Qbox loads the character.
3. Open `/cityapp` and confirm notices/history/contracts/property/insurance/corrections routes open without console errors.
4. Make a small `/paybank` transfer and confirm balances/audit records change once.
5. Open a mechanic order, claim it, quote it, pay it, then log into the mechanic character and collect the pending earning through `/banking`.
6. Buy a low-cost test vehicle from `/dealer city_motors`; verify Qbox owns it and it appears in `/mycars`.
7. Create a test property and buy it; verify a guest sees access but not owner-only controls.
8. Submit an insurance claim with a real evidence key and verify an adjuster can approve it and the claimant can collect exactly once.
9. Run one civic job and verify the player bank payment and district state change.
10. Run one underworld operation and one robbery with test police online; verify completion cannot occur away from the configured location.
11. Verify robbery start creates dispatch/witness records and completion creates evidence/rumor/district consequences.
12. Publish a news article and court ruling; verify both appear in their relevant public/legal interfaces.
13. Record a corrections sentence, mark the player incarcerated from the selected prison adapter, and verify served time increments only while the server-side incarceration state is true.

## Crafting safety

The sample v0.4 recipes shipped with LOTB each have a **single output item**. Keep production recipes single-output during initial testing. Before adding recipes with multiple output item types, extend the underworld crafting rollback to remove already-added outputs if a later output fails.

Ingredient removal and output creation are server-authoritative through ox_inventory; the client never grants itself inventory.

## Load/exploit test gates

Do not open the whitelist publicly until the staging server has tested:

- malformed/duplicate network events
- reconnects during payments/claims/contracts
- simultaneous vehicle/property purchases
- repeated robbery completion calls
- inventory full/failure cases
- resource restart persistence
- character switching
- OneSync entity behavior
- 25+, then 50+, then target-concurrency players
- server hitch warnings and slow SQL queries

A repository can be structurally correct without proving the exact production phone, prison, MLO, doorlock, vehicle, voice and inventory packs work together. Those combinations must be verified on the deployed server.
