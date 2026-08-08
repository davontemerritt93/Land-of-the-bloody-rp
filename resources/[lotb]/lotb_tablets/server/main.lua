local function groups(source)
    return exports.qbx_core:GetGroups(source) or {}
end

local function isPolice(source)
    if exports.lotb_core:HasAce(source, 'lotb.admin') or exports.lotb_core:HasAce(source, 'lotb.justice.manage') then return true end
    local g = groups(source)
    return g.police ~= nil or g.sheriff ~= nil or g.state ~= nil
end

local function isMedical(source)
    if exports.lotb_core:HasAce(source, 'lotb.admin') or exports.lotb_core:HasAce(source, 'lotb.medical.manage') then return true end
    local g = groups(source)
    return g.ambulance ~= nil or g.ems ~= nil or g.doctor ~= nil
end

local function isJustice(source)
    if exports.lotb_core:HasAce(source, 'lotb.admin') or exports.lotb_core:HasAce(source, 'lotb.justice.manage') then return true end
    local g = groups(source)
    return g.judge ~= nil or g.lawyer ~= nil or g.doj ~= nil or g.prosecutor ~= nil
end

lib.callback.register('lotb_tablets:policeOverview', function(source)
    if not isPolice(source) then return nil end
    return {
        dispatch = MySQL.query.await("SELECT call_key,service,message,status,created_at FROM lotb_dispatch_calls WHERE status='open' ORDER BY created_at DESC LIMIT 20") or {},
        warrants = MySQL.query.await("SELECT warrant_key,citizenid,case_key,reason,expires_at,created_at FROM lotb_warrants WHERE status='active' AND (expires_at IS NULL OR expires_at > NOW()) ORDER BY created_at DESC LIMIT 30") or {},
        witnesses = MySQL.query.await([[
            SELECT report_key,district,event_type,confidence,decay_rate,case_ref,created_at
            FROM lotb_witness_reports
            WHERE (expires_at IS NULL OR expires_at > NOW())
            ORDER BY created_at DESC LIMIT 20
        ]]) or {},
        cases = MySQL.query.await("SELECT case_key,title,status,summary,updated_at FROM lotb_justice_cases WHERE status!='closed' ORDER BY updated_at DESC LIMIT 20") or {}
    }
end)

lib.callback.register('lotb_tablets:citizenCase', function(source, citizenid)
    if not isPolice(source) and not isJustice(source) then return nil end
    citizenid = exports.lotb_core:CleanText(citizenid or '', 64)
    if citizenid == '' then return nil end
    return {
        warrants = MySQL.query.await("SELECT warrant_key,case_key,reason,status,expires_at,created_at FROM lotb_warrants WHERE citizenid=? ORDER BY created_at DESC LIMIT 20", { citizenid }) or {},
        memories = MySQL.query.await([[
            SELECT memory_type,SUM(weight) score FROM lotb_character_memory
            WHERE citizenid=? AND created_at > DATE_SUB(NOW(), INTERVAL 60 DAY)
            GROUP BY memory_type ORDER BY ABS(SUM(weight)) DESC LIMIT 10
        ]], { citizenid }) or {},
        medicalCount = MySQL.scalar.await('SELECT COUNT(*) FROM lotb_medical_records WHERE citizenid=?', { citizenid }) or 0,
        contracts = MySQL.query.await([[
            SELECT contract_key,title,status,amount,created_at FROM lotb_contracts
            WHERE creator_citizenid=? OR counterparty_citizenid=?
            ORDER BY created_at DESC LIMIT 15
        ]], { citizenid, citizenid }) or {}
    }
end)

lib.callback.register('lotb_tablets:evidenceForCase', function(source, caseKey)
    if not isPolice(source) and not isJustice(source) then return {} end
    caseKey = exports.lotb_core:CleanText(caseKey or '', 96)
    return MySQL.query.await([[
        SELECT evidence_key,evidence_type,integrity,created_by,created_at
        FROM lotb_evidence WHERE case_ref=? ORDER BY created_at DESC
    ]], { caseKey }) or {}
end)

lib.callback.register('lotb_tablets:medicalOverview', function(source)
    if not isMedical(source) then return nil end
    return MySQL.query.await([[
        SELECT record_key,citizenid,author_citizenid,record_type,summary,created_at
        FROM lotb_medical_records ORDER BY created_at DESC LIMIT 30
    ]]) or {}
end)

lib.callback.register('lotb_tablets:medicalCitizen', function(source, citizenid)
    if not isMedical(source) then return {} end
    citizenid = exports.lotb_core:CleanText(citizenid or '', 64)
    return MySQL.query.await([[
        SELECT record_key,author_citizenid,record_type,summary,created_at
        FROM lotb_medical_records WHERE citizenid=? ORDER BY created_at DESC LIMIT 30
    ]], { citizenid }) or {}
end)

lib.callback.register('lotb_tablets:justiceOverview', function(source)
    if not isJustice(source) then return nil end
    return {
        cases = MySQL.query.await('SELECT case_key,title,status,judge_citizenid,summary,updated_at FROM lotb_justice_cases ORDER BY updated_at DESC LIMIT 40') or {},
        warrants = MySQL.query.await('SELECT warrant_key,citizenid,case_key,reason,status,expires_at,created_at FROM lotb_warrants ORDER BY created_at DESC LIMIT 40') or {},
        contracts = MySQL.query.await("SELECT contract_key,creator_citizenid,counterparty_citizenid,title,amount,status,created_at FROM lotb_contracts WHERE status IN ('accepted','disputed','pending') ORDER BY created_at DESC LIMIT 30") or {}
    }
end)

exports('IsPolice', isPolice)
exports('IsMedical', isMedical)
exports('IsJustice', isJustice)
