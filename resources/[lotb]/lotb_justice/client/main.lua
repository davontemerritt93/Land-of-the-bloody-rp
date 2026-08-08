local function decodeList(value)
    if type(value) ~= 'string' or value == '' then return {} end
    local ok, data = pcall(json.decode, value)
    return ok and type(data) == 'table' and data or {}
end

RegisterCommand('caseview', function(_, args)
    local caseKey = args[1]
    if not caseKey then return lib.notify({ title = 'Justice', description = 'Usage: /caseview [case-key]', type = 'error' }) end
    local row = lib.callback.await('lotb_justice:getCase', false, caseKey)
    if not row then return lib.notify({ title = 'Justice', description = 'Case not found or access denied.', type = 'error' }) end

    local evidenceLines = {}
    for _, evidence in ipairs(row.evidence or {}) do
        evidenceLines[#evidenceLines + 1] = ('%s — %s (%s%% integrity)'):format(evidence.evidence_key, evidence.evidence_type, evidence.integrity)
    end
    local rulingLines = {}
    for _, ruling in ipairs(row.rulings or {}) do
        rulingLines[#rulingLines + 1] = ('%s — %s%s'):format(ruling.ruling_key, ruling.title, tonumber(ruling.precedential) == 1 and ' [precedent]' or '')
    end

    lib.alertDialog({
        header = ('%s — %s'):format(row.case_key, row.title),
        content = table.concat({
            ('Status: %s'):format(row.status),
            '',
            row.summary ~= '' and row.summary or 'No case summary has been filed.',
            '',
            'Evidence:',
            #evidenceLines > 0 and table.concat(evidenceLines, '\n') or 'No evidence attached.',
            '',
            'Published rulings:',
            #rulingLines > 0 and table.concat(rulingLines, '\n') or 'No rulings published.'
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

RegisterCommand('precedent', function(_, args)
    local query = table.concat(args, ' ')
    if query == '' then
        local input = lib.inputDialog('Search Legal Precedent', {
            { type = 'input', label = 'Search', description = 'Case key, topic, holding, rationale, or tag. Leave blank for recent rulings.' }
        })
        if not input then return end
        query = input[1] or ''
    end
    local rows = lib.callback.await('lotb_justice:searchPrecedent', false, query)
    if not rows then return lib.notify({ title = 'Justice', description = 'Court access required.', type = 'error' }) end
    local options = {}
    for _, row in ipairs(rows) do
        local tags = decodeList(row.tags_json)
        local citations = decodeList(row.citations_json)
        options[#options + 1] = {
            title = row.title,
            description = ('%s • Case %s%s\n%s'):format(row.ruling_key, row.case_key, tonumber(row.precedential) == 1 and ' • PRECEDENT' or '', row.holding),
            icon = 'scale-balanced',
            onSelect = function()
                lib.alertDialog({
                    header = row.title,
                    content = ('Ruling: %s\nCase: %s\nPrecedential: %s\n\nHOLDING\n%s\n\nRATIONALE\n%s\n\nTags: %s\nCites: %s'):format(
                        row.ruling_key, row.case_key, tonumber(row.precedential) == 1 and 'yes' or 'no', row.holding, row.rationale,
                        #tags > 0 and table.concat(tags, ', ') or 'none', #citations > 0 and table.concat(citations, ', ') or 'none'
                    ),
                    centered = true
                })
            end
        }
    end
    if #options == 0 then options[1] = { title = 'No matching rulings found' } end
    lib.registerContext({ id = 'lotb_precedent', title = 'LOTB Legal Precedent', options = options })
    lib.showContext('lotb_precedent')
end, false)

RegisterCommand('ruling', function()
    local input = lib.inputDialog('Publish Court Ruling', {
        { type = 'input', label = 'Case key', required = true },
        { type = 'input', label = 'Ruling title', required = true, max = 180 },
        { type = 'textarea', label = 'Holding', description = 'What did the court decide?', required = true, min = 20, max = 1200 },
        { type = 'textarea', label = 'Rationale', description = 'Why did the court decide it?', required = true, min = 20, max = 2000 },
        { type = 'input', label = 'Tags', description = 'Comma-separated: search, evidence, contracts, property...' },
        { type = 'input', label = 'Cited ruling keys', description = 'Comma-separated existing RULE-* keys' },
        { type = 'select', label = 'Precedential?', required = true, default = 'yes', options = { { value = 'yes', label = 'Yes' }, { value = 'no', label = 'No — case-specific only' } } },
        { type = 'select', label = 'Close the case?', required = true, default = 'no', options = { { value = 'no', label = 'No' }, { value = 'yes', label = 'Yes' } } }
    })
    if not input then return end
    TriggerServerEvent('lotb_justice:publishRuling', {
        caseKey = input[1], title = input[2], holding = input[3], rationale = input[4], tags = input[5] or '', citations = input[6] or '',
        precedential = input[7] == 'yes', closeCase = input[8] == 'yes'
    })
end, false)
