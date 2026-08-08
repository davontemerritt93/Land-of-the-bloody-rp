RegisterCommand('medical', function(_, args)
    local targetSource = tonumber(args[1])
    if not targetSource then return lib.notify({ title = 'Medical', description = 'Usage: /medical [player-id]', type = 'error' }) end
    local rows = lib.callback.await('lotb_medical:getBySource', false, targetSource) or {}
    if #rows == 0 then return lib.notify({ title = 'Medical', description = 'No records found or access denied.', type = 'inform' }) end

    local options = {}
    for _, row in ipairs(rows) do
        options[#options + 1] = { title = ('%s — %s'):format(row.record_type, row.record_key), description = row.summary, icon = 'notes-medical' }
    end
    lib.registerContext({ id = 'lotb_medical_ctx', title = 'Medical History', options = options })
    lib.showContext('lotb_medical_ctx')
end, false)
