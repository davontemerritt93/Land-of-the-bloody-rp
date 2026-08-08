local function confidenceText(value)
    value = tonumber(value) or 0
    if value >= 75 then return 'high confidence' end
    if value >= 45 then return 'mixed confidence' end
    if value >= 20 then return 'weak memory' end
    return 'memory is badly degraded'
end

RegisterCommand('witnesses', function(_, args)
    local rows = lib.callback.await('lotb_world:witnesses', false, args[1]) or {}
    if #rows == 0 then return lib.notify({ title = 'Witness Memory', description = 'No witness reports found or access denied.', type = 'inform' }) end

    local options = {}
    for _, row in ipairs(rows) do
        local statement = row.description and (row.description.statement or json.encode(row.description)) or 'No usable statement.'
        options[#options + 1] = {
            title = ('%s — %s'):format(row.report_key, confidenceText(row.effective_confidence)),
            description = ('%s\nDistrict: %s'):format(statement, row.district or 'unknown'),
            icon = 'eye'
        }
    end
    lib.registerContext({ id = 'lotb_witness_ctx', title = 'Witness Reports', options = options })
    lib.showContext('lotb_witness_ctx')
end, false)

RegisterCommand('objecthistory', function(_, args)
    local key = args[1]
    if not key then return lib.notify({ title = 'Object Legacy', description = 'Usage: /objecthistory [legacy-key]', type = 'error' }) end
    local row = lib.callback.await('lotb_world:legacy', false, key)
    if not row then return lib.notify({ title = 'Object Legacy', description = 'No registered history exists for that object.', type = 'inform' }) end

    local lines = { ('Type: %s'):format(row.object_type), ('Fame: %s'):format(row.fame or 0), '' }
    for _, event in ipairs(row.events or {}) do
        lines[#lines + 1] = ('• %s — %s'):format(event.event_type, event.summary)
    end
    if #(row.events or {}) == 0 then lines[#lines + 1] = 'No notable events have been recorded yet.' end
    lib.alertDialog({ header = ('%s — %s'):format(row.legacy_key, row.label), content = table.concat(lines, '\n'), centered = true })
end, false)

RegisterCommand('contacts', function()
    local rows = lib.callback.await('lotb_world:contacts', false) or {}
    if #rows == 0 then return lib.notify({ title = 'Contacts', description = 'You have not built a meaningful relationship with a named contact yet.', type = 'inform' }) end

    local options = {}
    for _, row in ipairs(rows) do
        local tone = row.trust >= 40 and 'They trust you.' or (row.fear >= 50 and 'They are wary of you.' or 'The relationship is still uncertain.')
        options[#options + 1] = {
            title = ('%s — %s'):format(row.name, row.role),
            description = ('%s\n%s\nDebt: %s'):format(row.public_description or '', tone, row.debt or 0),
            icon = 'address-book'
        }
    end
    lib.registerContext({ id = 'lotb_contacts_ctx', title = 'People Who Know You', options = options })
    lib.showContext('lotb_contacts_ctx')
end, false)
