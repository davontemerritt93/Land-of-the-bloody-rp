# LOTB Underworld / Mechanic Item Mapping

LOTB does not overwrite `ox_inventory` item definitions. The v0.4 sample recipes use placeholder item names so you can map them to the item pack you choose.

Default sample recipe names:

- `metals`
- `electronics`
- `rubber`
- `repairkit`
- `lockpick`

Before public launch, either define those items in your selected ox_inventory item configuration or edit `lotb_crafting_recipes` in `sql/lotb_v04.sql` to use item names that already exist on your server.

The crafting server validates all ingredients, verifies output capacity before consuming materials, performs item changes through ox_inventory exports, and restores removed materials when output creation fails.

Do not add contraband or progression items simply because a purchased script expects them. Keep the item list intentional and tie unlocks to LOTB contacts, character history and city conditions.
