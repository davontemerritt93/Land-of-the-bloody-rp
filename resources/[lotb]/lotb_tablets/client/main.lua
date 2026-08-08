local function showSimple(id, title, rows, builder)
    local options = {}
    for _, row in ipairs(rows or {}) do
        options[#options + 1] = builder(row)
    end
    if #options == 0 then options[1] = { title = 'Nothing to show' } end
    lib.registerContext({ id = id, title = title, options = options })
    lib.showContext(id)
end

local function citizenLookup()
    local input = lib.inputDialog('Citizen lookup', {{ type = 'input', label = 'Citizen ID', required = true }})
    if not input then return end
    local data = lib.callback.await('lotb_tablets:citizenCase', false, input[1])
    if not data then return lib.notify({ title = 'MDT', description = 'Lookup unavailable.', type = 'error' }) end
    local options = {
        { title = 'Active / historical warrants', description = tostring(#(data.warrants or {})), icon = 'gavel', onSelect = function()
            showSimple('lotb_mdt_cit_warrants', 'Citizen Warrants', data.warrants, function(row)
                return { title = row.warrant_key, description = ('%s — %s'):format(row.status, row.reason), icon = 'scale-balanced' }
            end)
        end },
        { title = 'Contracts / disputes', description = tostring(#(data.contracts or {})), icon = 'file-contract', onSelect = function()
            showSimple('lotb_mdt_cit_contracts', 'Citizen Contracts', data.contracts, function(row)
                return { title = row.title, description = ('%s • $%s'):format(row.status, row.amount or 0), icon = 'file-signature' }
            end)
        end }
    }
    lib.registerContext({ id = 'lotb_citizen_lookup', title = ('Citizen %s'):format(input[1]), options = options })
    lib.showContext('lotb_citizen_lookup')
end

RegisterCommand('mdt', function()
    local data = lib.callback.await('lotb_tablets:policeOverview', false)
    if not data then return lib.notify({ title = 'MDT', description = 'Law-enforcement access required.', type = 'error' }) end
    local options = {
        { title = 'Citizen lookup', icon = 'magnifying-glass', onSelect = citizenLookup },
        { title = 'Open dispatch', description = tostring(#data.dispatch), icon = 'tower-broadcast', onSelect = function()
            showSimple('lotb_mdt_dispatch', 'Open Dispatch', data.dispatch, function(row)
                return { title = ('%s • %s'):format(row.service, row.call_key), description = row.message, icon = 'radio' }
            end)
        end },
        { title = 'Active warrants', description = tostring(#data.warrants), icon = 'gavel', onSelect = function()
            showSimple('lotb_mdt_warrants', 'Active Warrants', data.warrants, function(row)
                return { title = row.citizenid, description = ('%s — %s'):format(row.warrant_key, row.reason), icon = 'person-circle-exclamation' }
            end)
        end },
        { title = 'Recent witness reports', description = tostring(#data.witnesses), icon = 'eye', onSelect = function()
            showSimple('lotb_mdt_witness', 'Witness Reports', data.witnesses, function(row)
                local confidence = tonumber(row.confidence) or 0
                local ageNote = confidence >= 70 and 'strong recollection' or confidence >= 40 and 'imperfect recollection' or 'weak recollection'
                return { title = row.event_type, description = ('%s • %s • %s'):format(row.district or 'unknown area', ageNote, row.report_key), icon = 'person-circle-question' }
            end)
        end },
        { title = 'Open cases', description = tostring(#data.cases), icon = 'folder-open', onSelect = function()
            showSimple('lotb_mdt_cases', 'Open Cases', data.cases, function(row)
                return { title = row.title, description = ('%s • %s'):format(row.case_key, row.summary or row.status), icon = 'folder-tree', onSelect = function()
                    local evidence = lib.callback.await('lotb_tablets:evidenceForCase', false, row.case_key) or {}
                    showSimple('lotb_case_evidence', 'Case Evidence', evidence, function(ev)
                        return { title = ev.evidence_type, description = ('%s • integrity %s/100'):format(ev.evidence_key, ev.integrity), icon = 'fingerprint' }
                    end)
                end }
            end)
        end }
    }
    lib.registerContext({ id = 'lotb_mdt', title = 'LOTB Police MDT', options = options })
    lib.showContext('lotb_mdt')
end, false)

RegisterCommand('emstablet', function()
    local rows = lib.callback.await('lotb_tablets:medicalOverview', false)
    if not rows then return lib.notify({ title = 'EMS', description = 'Medical access required.', type = 'error' }) end
    local options = {
        { title = 'Patient lookup', icon = 'user-doctor', onSelect = function()
            local input = lib.inputDialog('Patient lookup', {{ type = 'input', label = 'Citizen ID', required = true }})
            if not input then return end
            local history = lib.callback.await('lotb_tablets:medicalCitizen', false, input[1]) or {}
            showSimple('lotb_patient_history', ('Patient %s'):format(input[1]), history, function(row)
                return { title = row.record_type, description = row.summary, icon = 'notes-medical' }
            end)
        end }
    }
    for _, row in ipairs(rows) do
        options[#options + 1] = { title = ('%s • %s'):format(row.citizenid, row.record_type), description = row.summary, icon = 'file-medical' }
    end
    lib.registerContext({ id = 'lotb_ems_tablet', title = 'LOTB EMS Tablet', options = options })
    lib.showContext('lotb_ems_tablet')
end, false)

RegisterCommand('doj', function()
    local data = lib.callback.await('lotb_tablets:justiceOverview', false)
    if not data then return lib.notify({ title = 'DOJ', description = 'Justice access required.', type = 'error' }) end
    local options = {
        { title = 'Citizen lookup', icon = 'magnifying-glass', onSelect = citizenLookup },
        { title = 'Case docket', description = tostring(#data.cases), icon = 'landmark', onSelect = function()
            showSimple('lotb_doj_cases', 'Case Docket', data.cases, function(row)
                return { title = row.title, description = ('%s • %s'):format(row.case_key, row.status), icon = 'scale-balanced', onSelect = function()
                    local evidence = lib.callback.await('lotb_tablets:evidenceForCase', false, row.case_key) or {}
                    showSimple('lotb_doj_evidence', 'Evidence Exhibits', evidence, function(ev)
                        return { title = ev.evidence_type, description = ('%s • integrity %s/100'):format(ev.evidence_key, ev.integrity), icon = 'fingerprint' }
                    end)
                end }
            end)
        end },
        { title = 'Warrant docket', description = tostring(#data.warrants), icon = 'stamp', onSelect = function()
            showSimple('lotb_doj_warrants', 'Warrant Docket', data.warrants, function(row)
                return { title = row.citizenid, description = ('%s • %s — %s'):format(row.status, row.warrant_key, row.reason), icon = 'gavel' }
            end)
        end },
        { title = 'Contracts & disputes', description = tostring(#data.contracts), icon = 'file-contract', onSelect = function()
            showSimple('lotb_doj_contracts', 'Contracts & Disputes', data.contracts, function(row)
                return { title = row.title, description = ('%s • $%s • %s ↔ %s'):format(row.status, row.amount or 0, row.creator_citizenid, row.counterparty_citizenid), icon = 'handshake' }
            end)
        end }
    }
    lib.registerContext({ id = 'lotb_doj', title = 'LOTB DOJ Docket', options = options })
    lib.showContext('lotb_doj')
end, false)
