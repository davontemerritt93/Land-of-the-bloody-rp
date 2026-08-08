local function simple(id, title, rows, builder)
    local options = {}
    for _, row in ipairs(rows or {}) do options[#options + 1] = builder(row) end
    if #options == 0 then options[1] = { title = 'No records' } end
    lib.registerContext({ id = id, title = title, options = options })
    lib.showContext(id)
end

RegisterCommand('staffpanel', function()
    local data = lib.callback.await('lotb_admin:overview', false)
    if not data then return lib.notify({ title = 'Staff', description = 'Admin access required.', type = 'error' }) end

    local options = {
        { title = 'Recent audit trail', description = tostring(#data.audits), icon = 'list-check', onSelect = function()
            simple('lotb_staff_audits', 'Recent Audit Trail', data.audits, function(row)
                return { title = ('%s • %s'):format(row.category, row.action), description = ('Actor %s • target %s'):format(row.actor_citizenid or row.actor_source, row.target or 'none'), icon = 'clock-rotate-left' }
            end)
        end },
        { title = 'Player notes', icon = 'note-sticky', onSelect = function()
            local input = lib.inputDialog('Player staff notes', {{ type='input', label='Citizen ID', required=true }})
            if not input then return end
            local rows = lib.callback.await('lotb_admin:playerNotes', false, input[1]) or {}
            simple('lotb_staff_notes', ('Notes: %s'):format(input[1]), rows, function(row)
                return { title = row.note_type, description = row.body, icon = 'note-sticky' }
            end)
        end },
        { title = 'Add staff note', icon = 'pen-to-square', onSelect = function()
            local input = lib.inputDialog('Add staff note', {
                { type='input', label='Citizen ID', required=true },
                { type='select', label='Type', required=true, options={ {value='note',label='Note'}, {value='warning',label='Warning history'}, {value='commendation',label='Commendation'}, {value='investigation',label='Staff investigation'} } },
                { type='textarea', label='Details', max=800, required=true }
            })
            if input then TriggerServerEvent('lotb_admin:addNote', input[1], input[2], input[3]) end
        end },
        { title = 'Warn online player', icon = 'triangle-exclamation', onSelect = function()
            local input = lib.inputDialog('Staff warning', {
                { type='number', label='Server ID', min=1, required=true },
                { type='textarea', label='Warning', max=500, required=true }
            })
            if input then TriggerServerEvent('lotb_admin:warnOnline', input[1], input[2]) end
        end }
    }

    for _, row in ipairs(data.notes or {}) do
        options[#options + 1] = { title = ('%s • %s'):format(row.target_citizenid, row.note_type), description = row.body, icon = 'shield-halved' }
    end

    lib.registerContext({ id='lotb_staffpanel', title='LOTB Staff Panel', options=options })
    lib.showContext('lotb_staffpanel')
end, false)
