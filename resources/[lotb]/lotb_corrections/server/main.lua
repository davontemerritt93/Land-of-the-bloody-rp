local function makeKey(prefix)
    return ('%s-%d-%05d'):format(prefix, os.time(), math.random(0, 99999))
end

local function cid(source)
    return exports.lotb_core:GetCitizenId(source)
end

local function hasAnyGroup(groupTable, names)
    for _, name in ipairs(names) do if groupTable[name] ~= nil then return true end end
    return false
end

local function staffAccess(source)
    if exports.lotb_core:HasAce(source, 'lotb.admin') or exports.lotb_core:HasAce(source, 'lotb.justice.manage') then return true end
    return hasAnyGroup(exports.qbx_core:GetGroups(source) or {}, { 'corrections','doc','prison','guard','judge','doj' })
end

local function judgeAccess(source)
    if exports.lotb_core:HasAce(source, 'lotb.admin') or exports.lotb_core:HasAce(source, 'lotb.justice.manage') then return true end
    return hasAnyGroup(exports.qbx_core:GetGroups(source) or {}, { 'judge','doj' })
end

local function activeSentence(citizenid)
    return MySQL.single.await([[
        SELECT * FROM lotb_sentences WHERE citizenid=? AND status='active' ORDER BY started_at DESC LIMIT 1
    ]], { citizenid })
end
exports('GetActiveSentence', activeSentence)

local function ensureProfile(citizenid)
    MySQL.insert.await('INSERT IGNORE INTO lotb_inmate_profiles(citizenid) VALUES(?)', { citizenid })
    return MySQL.single.await('SELECT * FROM lotb_inmate_profiles WHERE citizenid=?', { citizenid })
end

local function addServedMinutes(citizenid, minutes, reason)
    minutes = math.max(0, math.min(1440, math.floor(tonumber(minutes) or 0)))
    if minutes <= 0 then return false end
    local sentence = activeSentence(citizenid)
    if not sentence then return false end
    local nextServed = math.min(sentence.total_minutes, (sentence.served_minutes or 0) + minutes)
    local status = nextServed >= sentence.total_minutes and 'completed' or 'active'
    MySQL.update.await([[
        UPDATE lotb_sentences SET served_minutes=?,status=?,released_at=IF(?='completed',NOW(),released_at)
        WHERE sentence_key=? AND status='active'
    ]], { nextServed, status, status, sentence.sentence_key })
    if reason then
        MySQL.insert.await([[
            INSERT INTO lotb_corrections_events(event_key,citizenid,event_type,summary)
            VALUES(?,?, 'time_credit', ?)
        ]], { makeKey('CORR'), citizenid, exports.lotb_core:CleanText(reason, 800) })
    end
    return true, nextServed, status
end
exports('AddServedMinutes', addServedMinutes)

exports('MarkIncarcerated', function(source, value)
    source = tonumber(source)
    if not source or not GetPlayerName(source) then return false end
    local citizenid = cid(source)
    if not citizenid or not activeSentence(citizenid) then return false end
    Player(source).state:set('lotbIncarcerated', value == true, true)
    return true
end)

lib.callback.register('lotb_corrections:mine', function(source)
    local citizenid = cid(source)
    if not citizenid then return nil end
    local sentence = activeSentence(citizenid)
    local profile = ensureProfile(citizenid)
    local events = MySQL.query.await([[
        SELECT event_key,event_type,summary,conduct_delta,program_credit_delta,created_at
        FROM lotb_corrections_events WHERE citizenid=? ORDER BY created_at DESC LIMIT 20
    ]], { citizenid }) or {}
    local visits = MySQL.query.await([[
        SELECT visit_key,inmate_citizenid,visitor_citizenid,status,scheduled_at,note,created_at
        FROM lotb_visitation_requests WHERE inmate_citizenid=? OR visitor_citizenid=? ORDER BY created_at DESC LIMIT 20
    ]], { citizenid, citizenid }) or {}
    return { sentence = sentence, profile = profile, events = events, visits = visits }
end)

lib.callback.register('lotb_corrections:staffLookup', function(source, citizenid)
    if not staffAccess(source) then return nil end
    citizenid = exports.lotb_core:CleanText(citizenid or '', 64)
    if citizenid == '' then return nil end
    return {
        sentence = activeSentence(citizenid),
        profile = ensureProfile(citizenid),
        events = MySQL.query.await('SELECT * FROM lotb_corrections_events WHERE citizenid=? ORDER BY created_at DESC LIMIT 40', { citizenid }) or {},
        visits = MySQL.query.await('SELECT * FROM lotb_visitation_requests WHERE inmate_citizenid=? ORDER BY created_at DESC LIMIT 30', { citizenid }) or {}
    }
end)

lib.callback.register('lotb_corrections:visitQueue', function(source)
    if not staffAccess(source) then return nil end
    return MySQL.query.await("SELECT * FROM lotb_visitation_requests WHERE status='requested' ORDER BY created_at ASC LIMIT 50") or {}
end)

RegisterNetEvent('lotb_corrections:imposeSentence', function(data)
    local source = source
    if not judgeAccess(source) or type(data) ~= 'table' then return end
    local citizenid = exports.lotb_core:CleanText(data.citizenid or '', 64)
    local caseKey = exports.lotb_core:CleanText(data.caseKey or '', 96)
    local notes = exports.lotb_core:CleanText(data.notes or '', 1200)
    local minutes = math.max(1, math.min(10080, math.floor(tonumber(data.minutes) or 0)))
    local paroleAfter = math.max(0, math.min(minutes, math.floor(tonumber(data.paroleAfter) or 0)))
    if citizenid == '' then return end
    if activeSentence(citizenid) then return exports.lotb_core:Notify(source, 'That character already has an active sentence.', 'error') end
    if caseKey ~= '' and not MySQL.scalar.await('SELECT 1 FROM lotb_justice_cases WHERE case_key=? LIMIT 1', { caseKey }) then
        return exports.lotb_core:Notify(source, 'Case key not found.', 'error')
    end

    local sentenceKey = makeKey('SENT')
    MySQL.insert.await([[
        INSERT INTO lotb_sentences(sentence_key,citizenid,case_key,imposed_by_citizenid,total_minutes,parole_after_minutes,notes)
        VALUES(?,?,NULLIF(?,''),?,?,?,?,?)
    ]], { sentenceKey, citizenid, caseKey, cid(source), minutes, paroleAfter > 0 and paroleAfter or nil, notes })
    ensureProfile(citizenid)
    exports.lotb_core:Audit('corrections', source, 'impose_sentence', sentenceKey, { citizenid = citizenid, case = caseKey, minutes = minutes, paroleAfter = paroleAfter })
    exports.lotb_core:Notify(source, ('Sentence recorded: %s'):format(sentenceKey), 'success')
end)

RegisterNetEvent('lotb_corrections:recordEvent', function(data)
    local source = source
    if not staffAccess(source) or type(data) ~= 'table' then return end
    local citizenid = exports.lotb_core:CleanText(data.citizenid or '', 64)
    local eventType = exports.lotb_core:CleanText(data.eventType or 'note', 64)
    local summary = exports.lotb_core:CleanText(data.summary or '', 800)
    local conduct = math.max(-20, math.min(20, math.floor(tonumber(data.conduct) or 0)))
    local credit = math.max(-20, math.min(20, math.floor(tonumber(data.credit) or 0)))
    if citizenid == '' or summary == '' then return end
    ensureProfile(citizenid)
    MySQL.insert.await([[
        INSERT INTO lotb_corrections_events(event_key,citizenid,event_type,summary,conduct_delta,program_credit_delta,recorded_by_citizenid)
        VALUES(?,?,?,?,?,?,?)
    ]], { makeKey('CORR'), citizenid, eventType, summary, conduct, credit, cid(source) })
    MySQL.update.await([[
        UPDATE lotb_inmate_profiles SET conduct=GREATEST(-100,LEAST(100,conduct+?)),program_credit=GREATEST(0,LEAST(100,program_credit+?)) WHERE citizenid=?
    ]], { conduct, credit, citizenid })
    exports.lotb_core:Audit('corrections', source, 'record_event', citizenid, { type = eventType, conduct = conduct, credit = credit })
    exports.lotb_core:Notify(source, 'Corrections event recorded.', 'success')
end)

RegisterNetEvent('lotb_corrections:parole', function(citizenid, decision, note)
    local source = source
    if not judgeAccess(source) then return end
    citizenid = exports.lotb_core:CleanText(citizenid or '', 64)
    note = exports.lotb_core:CleanText(note or '', 800)
    local sentence = activeSentence(citizenid)
    if not sentence then return end
    local profile = ensureProfile(citizenid)
    local eligible = sentence.parole_after_minutes and sentence.served_minutes >= sentence.parole_after_minutes
    if decision == 'approve' and not eligible then return exports.lotb_core:Notify(source, 'The sentence is not parole-eligible yet.', 'error') end
    if decision == 'approve' then
        MySQL.update.await("UPDATE lotb_sentences SET status='paroled',released_at=NOW() WHERE sentence_key=? AND status='active'", { sentence.sentence_key })
        MySQL.insert.await([[
            INSERT INTO lotb_corrections_events(event_key,citizenid,event_type,summary,recorded_by_citizenid)
            VALUES(?,?, 'parole_granted', ?, ?)
        ]], { makeKey('CORR'), citizenid, note ~= '' and note or 'Parole granted.', cid(source) })
        exports.lotb_core:Audit('corrections', source, 'parole_granted', sentence.sentence_key, { citizenid = citizenid, conduct = profile.conduct, credit = profile.program_credit })
        exports.lotb_core:Notify(source, 'Parole granted.', 'success')
    else
        MySQL.insert.await([[
            INSERT INTO lotb_corrections_events(event_key,citizenid,event_type,summary,recorded_by_citizenid)
            VALUES(?,?, 'parole_denied', ?, ?)
        ]], { makeKey('CORR'), citizenid, note ~= '' and note or 'Parole denied.', cid(source) })
        exports.lotb_core:Audit('corrections', source, 'parole_denied', sentence.sentence_key, { citizenid = citizenid })
        exports.lotb_core:Notify(source, 'Parole decision recorded.', 'success')
    end
end)

RegisterNetEvent('lotb_corrections:requestVisit', function(inmateCitizenId, note)
    local source = source
    local visitor = cid(source)
    inmateCitizenId = exports.lotb_core:CleanText(inmateCitizenId or '', 64)
    note = exports.lotb_core:CleanText(note or '', 500)
    if not visitor or inmateCitizenId == '' or visitor == inmateCitizenId then return end
    if not activeSentence(inmateCitizenId) then return exports.lotb_core:Notify(source, 'That character has no active corrections record.', 'error') end
    local open = MySQL.scalar.await("SELECT 1 FROM lotb_visitation_requests WHERE inmate_citizenid=? AND visitor_citizenid=? AND status IN ('requested','approved') LIMIT 1", { inmateCitizenId, visitor })
    if open then return exports.lotb_core:Notify(source, 'You already have a pending/approved visit request.', 'error') end
    local visitKey = makeKey('VISIT')
    MySQL.insert.await('INSERT INTO lotb_visitation_requests(visit_key,inmate_citizenid,visitor_citizenid,note) VALUES(?,?,?,?)', { visitKey, inmateCitizenId, visitor, note })
    exports.lotb_core:Audit('corrections', source, 'visit_request', visitKey, { inmate = inmateCitizenId })
    exports.lotb_core:Notify(source, ('Visit requested: %s'):format(visitKey), 'success')
end)

RegisterNetEvent('lotb_corrections:reviewVisit', function(visitKey, decision, note)
    local source = source
    if not staffAccess(source) then return end
    decision = decision == 'approve' and 'approved' or 'denied'
    note = exports.lotb_core:CleanText(note or '', 500)
    local affected = MySQL.update.await([[
        UPDATE lotb_visitation_requests SET status=?,note=CASE WHEN ?='' THEN note ELSE ? END WHERE visit_key=? AND status='requested'
    ]], { decision, note, note, visitKey })
    if affected and affected > 0 then
        exports.lotb_core:Audit('corrections', source, 'visit_review', visitKey, { decision = decision })
        exports.lotb_core:Notify(source, ('Visit %s.'):format(decision), 'success')
    end
end)

CreateThread(function()
    while true do
        Wait(60 * 1000)
        for _, playerId in ipairs(GetPlayers()) do
            local source = tonumber(playerId)
            if Player(source).state.lotbIncarcerated == true then
                local citizenid = cid(source)
                if citizenid then
                    local ok, _, status = addServedMinutes(citizenid, 1)
                    if ok and status == 'completed' then
                        Player(source).state:set('lotbIncarcerated', false, true)
                        exports.qbx_core:Notify(source, 'Your recorded sentence has been completed. Corrections staff still control physical release.', 'success', 8000)
                    end
                end
            end
        end
    end
end)

exports('StaffAccess', staffAccess)
exports('JudgeAccess', judgeAccess)
