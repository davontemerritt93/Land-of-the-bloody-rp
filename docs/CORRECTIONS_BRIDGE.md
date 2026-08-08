# LOTB Corrections / Prison Bridge

`lotb_corrections` owns the **legal sentence record**. A prison MLO/jail resource should own teleporting, doors, uniforms, cells and physical prison gameplay.

This separation keeps cases, sentence history, parole and visitation stable even if the prison resource changes.

## Get a sentence

```lua
local sentence = exports.lotb_corrections:GetActiveSentence(citizenid)
```

Important fields include:

- `sentence_key`
- `citizenid`
- `case_key`
- `total_minutes`
- `served_minutes`
- `parole_after_minutes`
- `notes`

## Mark a player physically incarcerated

After your jail resource has actually moved/accepted a player into custody:

```lua
exports.lotb_corrections:MarkIncarcerated(source, true)
```

While that server-side state is true, LOTB records one served minute for each connected minute. When the legal sentence reaches its total, LOTB stops its timer. Your prison resource/staff still controls the physical release flow.

On physical release/escape/transfer:

```lua
exports.lotb_corrections:MarkIncarcerated(source, false)
```

## Add sentence credit from another prison system

A prison job/program can award time credit through:

```lua
exports.lotb_corrections:AddServedMinutes(citizenid, minutes, 'Completed approved prison program')
```

Do not call this from an untrusted client event.

## Commands / fallback UI

- `/corrections` — personal sentence, institutional record and visitation.
- `/sentence` — judge/justice sentence entry.
- `/correctionsstaff` — corrections lookup and program/conduct events.
- `/visitqueue` — visitation approval queue.

## Design rule

A sentence is not just a countdown. Corrections staff can record conduct, institutional incidents and program progress; judges can use the persistent record during parole RP. LOTB does not auto-decide parole based on a score.
