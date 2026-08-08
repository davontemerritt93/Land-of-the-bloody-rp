RegisterCommand('caseview', function(_, args)
    local caseKey = args[1]
    if not caseKey then return lib.notify({ title = 'Justice', description = 'Usage: /caseview [case-key]', type = 'error' }) end
    local row = lib.callback.await('lotb_justice:getCase', false, caseKey)
    if not row then return lib.notify({ title = 'Justice', description = 'Case not found or access denied.', type = 'error' }) end

    local evidenceLines = {}
    for _, evidence in ipairs(row.evidence or {}) do
        evidenceLines[#evidenceLines + 1] = ('%s — %s (%s%% integrity)'):format(evidence.evidence_key, evidence.evidence_type, evidence.integrity)
    end

    lib.alertDialog({
        header = ('%s — %s'):format(row.case_key, row.title),
        content = table.concat({
            ('Status: %s'):format(row.status),
            '',
            row.summary ~= '' and row.summary or 'No case summary has been filed.',
            '',
            'Evidence:',
            #evidenceLines > 0 and table.concat(evidenceLines, '\n') or 'No evidence attached.'
        }, '\n'),
        centered = true
    })
end, false)

RegisterCommand('warrants', function(_, args)
    local targetSource = tonumber(args[1])
    if not targetSource then return lib.notify({ title = 'Justice', description = 'Usage: /warrants [player-id]', type = 'error' }) end
    local rows = lib.callback.await('lotb_justice:getWarrantsBySource', false, targetSource) or {}
    if #rows == 0 then return lib.notify({ title = 'Justice', description = 'No active warrants found or access denied.', type = 'inform' }) end

    local options = {}
    for _, row in ipairs(rows) do
        options[#options + 1] = { title = row.warrant_key, description = ('Case: %s\n%s'):format(row.case_key or 'none', row.reason), icon = 'scale-balanced' }
    end
    lib.registerContext({ id = 'lotb_warrants_ctx', title = 'Active Warrants', options = options })
    lib.showContext('lotb_warrants_ctx')
end, false)
