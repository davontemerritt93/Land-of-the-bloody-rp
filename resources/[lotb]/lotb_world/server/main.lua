local function makeKey(prefix)
    return ('%s-%d-%05d'):format(prefix, os.time(), math.random(0, 99999))
end

local function justiceAccess(source)
    if source == 0 then return true end
    if exports.lotb_core:HasAce(source, 'lotb.justice.manage') then return true end
    return exports.qbx_core:HasGroup(source, { police = 0 }) == true
end

local function createWitness(data)
    if type(data) ~= 'table' or type(data.eventType) ~= 'string' or type(data.description) ~= 'table' then return nil end
    local key = data.key or makeKey('WIT')
    local confidence = math.max(1, math.min(100, math.floor(tonumber(data.confidence) or 55)))
    local decayRate = math.max(0, math.min(20, math.floor(tonumber(data.decayRate) or 2)))

    MySQL.insert.await([[
        INSERT INTO lotb_witness_reports
            (report_key, district, event_type, description_json, confidence, decay_rate, source_kind, case_ref, expires_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        key,
        data.district,
        exports.lotb_core:CleanText(data.eventType, 64),
        json.encode(data.description),
        confidence,
        decayRate,
        exports.lotb_core:CleanText(data.sourceKind or 'npc', 32),
        data.caseRef,
        data.expiresAt
    })
    return key
end
exports('CreateWitnessReport', createWitness)

exports('RegisterLegacyObject', function(data)
    if type(data) ~= 'table' or type(data.key) ~= 'string' or type(data.type) ~= 'string' or type(data.label) ~= 'string' then return false end
    MySQL.insert.await([[
        INSERT INTO lotb_object_legacy (legacy_key, object_type, label, owner_citizenid, metadata_json, fame)
        VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE object_type = VALUES(object_type), label = VALUES(label), owner_citizenid = VALUES(owner_citizenid), metadata_json = VALUES(metadata_json)
    ]], {
        exports.lotb_core:CleanText(data.key, 96),
        exports.lotb_core:CleanText(data.type, 48),
        exports.lotb_core:CleanText(data.label, 128),
        data.ownerCitizenId,
        json.encode(type(data.metadata) == 'table' and data.metadata or {}),
        math.max(0, math.min(100, math.floor(tonumber(data.fame) or 0)))
    })
    return true
end)

exports('AddLegacyEvent', function(legacyKey, eventType, summary, actorCitizenId, district, importance)
    importance = math.max(1, math.min(10, math.floor(tonumber(importance) or 1)))
    local exists = MySQL.scalar.await('SELECT 1 FROM lotb_object_legacy WHERE legacy_key = ? LIMIT 1', { legacyKey })
    if not exists then return false end
    MySQL.insert.await([[
        INSERT INTO lotb_object_legacy_events (legacy_key, event_type, summary, actor_citizenid, district, importance)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], {
        legacyKey,
        exports.lotb_core:CleanText(eventType, 64),
        exports.lotb_core:CleanText(summary, 500),
        actorCitizenId,
        district,
        importance
    })
    MySQL.update.await('UPDATE lotb_object_legacy SET fame = LEAST(100, fame + ?) WHERE legacy_key = ?', { importance, legacyKey })
    return true
end)

exports('AdjustContact', function(citizenid, contactKey, trustDelta, fearDelta, debtDelta)
    if type(citizenid) ~= 'string' or type(contactKey) ~= 'string' then return false end
    trustDelta = math.floor(tonumber(trustDelta) or 0)
    fearDelta = math.floor(tonumber(fearDelta) or 0)
    debtDelta = math.floor(tonumber(debtDelta) or 0)
    local exists = MySQL.scalar.await('SELECT 1 FROM lotb_city_contacts WHERE contact_key = ? AND active = 1 LIMIT 1', { contactKey })
    if not exists then return false end

    MySQL.insert.await([[
        INSERT INTO lotb_character_contacts (citizenid, contact_key, trust, fear, debt)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            trust = GREATEST(-100, LEAST(100, trust + VALUES(trust))),
            fear = GREATEST(0, LEAST(100, fear + VALUES(fear))),
            debt = debt + VALUES(debt)
    ]], { citizenid, contactKey, trustDelta, fearDelta, debtDelta })
    return true
end)

lib.callback.register('lotb_world:witnesses', function(source, caseRef)
    if not justiceAccess(source) then return {} end
    local sql = [[
        SELECT report_key, district, event_type, description_json, source_kind, case_ref, created_at,
               GREATEST(0, confidence - (decay_rate * TIMESTAMPDIFF(HOUR, created_at, NOW()))) AS effective_confidence
        FROM lotb_witness_reports
        WHERE (expires_at IS NULL OR expires_at > NOW())
    ]]
    local params = {}
    if type(caseRef) == 'string' and caseRef ~= '' then
        sql = sql .. ' AND case_ref = ?'
        params[1] = caseRef
    end
    sql = sql .. ' ORDER BY created_at DESC LIMIT 25'
    local rows = MySQL.query.await(sql, params) or {}
    for _, row in ipairs(rows) do
        row.description = row.description_json and json.decode(row.description_json) or {}
        row.description_json = nil
        row.effective_confidence = tonumber(row.effective_confidence) or 0
    end
    return rows
end)

lib.callback.register('lotb_world:legacy', function(_, legacyKey)
    if type(legacyKey) ~= 'string' then return nil end
    local row = MySQL.single.await('SELECT legacy_key, object_type, label, owner_citizenid, fame, created_at FROM lotb_object_legacy WHERE legacy_key = ?', { legacyKey })
    if not row then return nil end
    row.events = MySQL.query.await([[
        SELECT event_type, summary, actor_citizenid, district, importance, created_at
        FROM lotb_object_legacy_events WHERE legacy_key = ? ORDER BY created_at ASC LIMIT 50
    ]], { legacyKey }) or {}
    return row
end)

lib.callback.register('lotb_world:contacts', function(source)
    local citizenid = exports.lotb_core:GetCitizenId(source)
    if not citizenid then return {} end
    return MySQL.query.await([[
        SELECT c.contact_key, c.name, c.district, c.role, c.public_description,
               COALESCE(cc.trust, 0) AS trust, COALESCE(cc.fear, 0) AS fear, COALESCE(cc.debt, 0) AS debt
        FROM lotb_city_contacts c
        LEFT JOIN lotb_character_contacts cc ON cc.contact_key = c.contact_key AND cc.citizenid = ?
        WHERE c.active = 1 AND cc.citizenid IS NOT NULL
        ORDER BY cc.last_interaction DESC
    ]], { citizenid }) or {}
end)

RegisterCommand('witnesscreate', function(source, args)
    if not justiceAccess(source) then return end
    local eventType = args[1]
    local confidence = tonumber(args[2])
    local caseRef = args[3]
    local description = table.concat(args, ' ', 4)
    if not eventType or not confidence or #description < 5 then
        return exports.lotb_core:Notify(source, 'Usage: /witnesscreate [event-type] [confidence] [case-ref-or-none] [description]', 'error')
    end
    local district = Player(source).state.lotbDistrict or 'county'
    local reportKey = createWitness({
        eventType = eventType,
        confidence = confidence,
        decayRate = 2,
        district = district,
        caseRef = caseRef ~= 'none' and caseRef or nil,
        description = { statement = exports.lotb_core:CleanText(description, 500) },
        sourceKind = 'npc'
    })
    exports.lotb_core:Audit('witness', source, 'create', reportKey, { eventType = eventType, district = district, caseRef = caseRef })
    exports.lotb_core:Notify(source, ('Witness report created: %s'):format(reportKey), 'success')
end, false)

RegisterCommand('legacycreate', function(source, args)
    if not exports.lotb_core:HasAce(source, 'lotb.admin') then return end
    local objectType, legacyKey = args[1], args[2]
    local label = table.concat(args, ' ', 3)
    if not objectType or not legacyKey or label == '' then return exports.lotb_core:Notify(source, 'Usage: /legacycreate [type] [key] [label]', 'error') end
    local ok = exports.lotb_world:RegisterLegacyObject({ key = legacyKey, type = objectType, label = label })
    if ok then exports.lotb_core:Notify(source, 'Legacy object registered.', 'success') end
end, false)

RegisterCommand('legacyadd', function(source, args)
    if not exports.lotb_core:HasAce(source, 'lotb.admin') then return end
    local legacyKey, eventType, importance = args[1], args[2], tonumber(args[3])
    local summary = table.concat(args, ' ', 4)
    if not legacyKey or not eventType or not importance or summary == '' then return exports.lotb_core:Notify(source, 'Usage: /legacyadd [key] [event-type] [importance 1-10] [summary]', 'error') end
    local ok = exports.lotb_world:AddLegacyEvent(legacyKey, eventType, summary, exports.lotb_core:GetCitizenId(source), Player(source).state.lotbDistrict, importance)
    if ok then exports.lotb_core:Notify(source, 'Legacy event recorded.', 'success') end
end, false)

RegisterCommand('contactstanding', function(source, args)
    if not exports.lotb_core:HasAce(source, 'lotb.admin') then return end
    local target = tonumber(args[1])
    local contactKey = args[2]
    local trust, fear, debt = tonumber(args[3]) or 0, tonumber(args[4]) or 0, tonumber(args[5]) or 0
    local player = target and exports.qbx_core:GetPlayer(target) or nil
    if not player or not contactKey then return exports.lotb_core:Notify(source, 'Usage: /contactstanding [player-id] [contact-key] [trust] [fear] [debt]', 'error') end
    local ok = exports.lotb_world:AdjustContact(player.PlayerData.citizenid, contactKey, trust, fear, debt)
    if ok then exports.lotb_core:Notify(source, 'Contact relationship updated.', 'success') end
end, false)
