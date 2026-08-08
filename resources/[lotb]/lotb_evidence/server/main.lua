local function key(prefix)
    return ('%s-%d-%05d'):format(prefix, os.time(), math.random(0, 99999))
end

local function canView(source)
    if source == 0 then return true end
    if exports.lotb_core:HasAce(source, 'lotb.justice.manage') then return true end
    return exports.qbx_core:HasGroup(source, { police = 0 }) == true
end

local function createEvidence(data)
    if type(data) ~= 'table' or type(data.type) ~= 'string' or data.type == '' then return nil end
    local evidenceKey = data.key or key('EV')
    local integrity = math.max(0, math.min(100, math.floor(tonumber(data.integrity) or 100)))

    MySQL.insert.await([[
        INSERT INTO lotb_evidence
            (evidence_key, evidence_type, case_ref, created_by, origin_json, metadata_json, integrity)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        evidenceKey,
        exports.lotb_core:CleanText(data.type, 64),
        data.caseRef,
        data.createdByCitizenId,
        json.encode(type(data.origin) == 'table' and data.origin or {}),
        json.encode(type(data.metadata) == 'table' and data.metadata or {}),
        integrity
    })

    if data.initialHolder then
        MySQL.insert.await([[
            INSERT INTO lotb_evidence_custody
                (evidence_key, from_holder, to_holder, reason, handled_by_citizenid)
            VALUES (?, NULL, ?, 'evidence created', ?)
        ]], { evidenceKey, exports.lotb_core:CleanText(data.initialHolder, 96), data.createdByCitizenId })
    end

    return evidenceKey
end
exports('CreateEvidence', createEvidence)

exports('TransferCustody', function(evidenceKey, fromHolder, toHolder, reason, handledByCitizenId)
    if type(evidenceKey) ~= 'string' or type(toHolder) ~= 'string' or toHolder == '' then return false end
    local exists = MySQL.scalar.await('SELECT 1 FROM lotb_evidence WHERE evidence_key = ? LIMIT 1', { evidenceKey })
    if not exists then return false end

    MySQL.insert.await([[
        INSERT INTO lotb_evidence_custody
            (evidence_key, from_holder, to_holder, reason, handled_by_citizenid)
        VALUES (?, ?, ?, ?, ?)
    ]], {
        evidenceKey,
        fromHolder and exports.lotb_core:CleanText(fromHolder, 96) or nil,
        exports.lotb_core:CleanText(toHolder, 96),
        exports.lotb_core:CleanText(reason or 'transfer', 160),
        handledByCitizenId
    })
    return true
end)

exports('DamageIntegrity', function(evidenceKey, amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    local affected = MySQL.update.await([[
        UPDATE lotb_evidence SET integrity = GREATEST(0, integrity - ?) WHERE evidence_key = ?
    ]], { amount, evidenceKey })
    return affected and affected > 0
end)

local function getEvidence(evidenceKey)
    local evidence = MySQL.single.await('SELECT * FROM lotb_evidence WHERE evidence_key = ?', { evidenceKey })
    if not evidence then return nil end
    evidence.origin = evidence.origin_json and json.decode(evidence.origin_json) or {}
    evidence.metadata = evidence.metadata_json and json.decode(evidence.metadata_json) or {}
    evidence.origin_json = nil
    evidence.metadata_json = nil
    evidence.custody = MySQL.query.await([[
        SELECT from_holder, to_holder, reason, handled_by_citizenid, created_at
        FROM lotb_evidence_custody WHERE evidence_key = ? ORDER BY id ASC
    ]], { evidenceKey }) or {}
    return evidence
end
exports('GetEvidence', getEvidence)

lib.callback.register('lotb_evidence:get', function(source, evidenceKey)
    if not canView(source) or type(evidenceKey) ~= 'string' then return nil end
    return getEvidence(evidenceKey)
end)

RegisterCommand('evidencecreate', function(source, args)
    if not canView(source) then return end
    local evidenceType = args[1]
    if not evidenceType then return exports.lotb_core:Notify(source, 'Usage: /evidencecreate [type] [case-ref optional]', 'error') end
    local citizenid = exports.lotb_core:GetCitizenId(source)
    local ped = GetPlayerPed(source)
    local coords = ped and ped ~= 0 and GetEntityCoords(ped) or vector3(0, 0, 0)
    local evidenceKey = createEvidence({
        type = evidenceType,
        caseRef = args[2],
        createdByCitizenId = citizenid,
        initialHolder = 'field collection',
        origin = { x = coords.x, y = coords.y, z = coords.z },
        metadata = { note = table.concat(args, ' ', 3) }
    })
    exports.lotb_core:Audit('evidence', source, 'create', evidenceKey, { type = evidenceType, caseRef = args[2] })
    exports.lotb_core:Notify(source, ('Evidence created: %s'):format(evidenceKey), 'success')
end, false)
