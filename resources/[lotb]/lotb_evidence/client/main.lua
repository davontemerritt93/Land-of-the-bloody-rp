RegisterCommand('evidence', function(_, args)
    local evidenceKey = args[1]
    if not evidenceKey then
        return lib.notify({ title = 'Evidence', description = 'Usage: /evidence [evidence-key]', type = 'error' })
    end

    local row = lib.callback.await('lotb_evidence:get', false, evidenceKey)
    if not row then
        return lib.notify({ title = 'Evidence', description = 'Evidence not found or access denied.', type = 'error' })
    end

    local custody = {}
    for _, entry in ipairs(row.custody or {}) do
        custody[#custody + 1] = ('%s → %s (%s)'):format(entry.from_holder or 'origin', entry.to_holder or '?', entry.reason or 'transfer')
    end

    local content = table.concat({
        ('Type: %s'):format(row.evidence_type),
        ('Case: %s'):format(row.case_ref or 'unassigned'),
        ('Integrity: %s%%'):format(row.integrity or 0),
        '',
        'Chain of custody:',
        #custody > 0 and table.concat(custody, '\n') or 'No custody events recorded.'
    }, '\n')

    lib.alertDialog({ header = ('Evidence %s'):format(evidenceKey), content = content, centered = true })
end, false)
