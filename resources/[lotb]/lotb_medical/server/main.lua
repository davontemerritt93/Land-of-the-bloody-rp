local function medicalAccess(source)
    if source == 0 then return true end
    if exports.lotb_core:HasAce(source, 'lotb.medical.manage') then return true end
    return exports.qbx_core:HasGroup(source, { ambulance = 0 }) == true
end

local function recordKey()
    return ('MED-%d-%04d'):format(os.time(), math.random(0, 9999))
end

lib.callback.register('lotb_medical:getBySource', function(source, targetSource)
    if not medicalAccess(source) then return {} end
    targetSource = tonumber(targetSource)
    local target = targetSource and exports.qbx_core:GetPlayer(targetSource) or nil
    if not target then return {} end
    return MySQL.query.await([[
        SELECT record_key, record_type, summary, author_citizenid, created_at
        FROM lotb_medical_records
        WHERE citizenid = ? ORDER BY created_at DESC LIMIT 25
    ]], { target.PlayerData.citizenid }) or {}
end)

RegisterCommand('medicaladd', function(source, args)
    if not medicalAccess(source) then return end
    local targetSource = tonumber(args[1])
    local recordType = args[2]
    local summary = table.concat(args, ' ', 3)
    local target = targetSource and exports.qbx_core:GetPlayer(targetSource) or nil
    if not target or not recordType or #summary < 5 then
        return exports.lotb_core:Notify(source, 'Usage: /medicaladd [player-id] [type] [summary]', 'error')
    end

    local key = recordKey()
    MySQL.insert.await([[
        INSERT INTO lotb_medical_records
            (record_key, citizenid, author_citizenid, record_type, summary, private_json)
        VALUES (?, ?, ?, ?, ?, '{}')
    ]], {
        key,
        target.PlayerData.citizenid,
        exports.lotb_core:GetCitizenId(source),
        exports.lotb_core:CleanText(recordType, 64),
        exports.lotb_core:CleanText(summary, 800)
    })

    exports.lotb_core:Audit('medical', source, 'add_record', key, { target = target.PlayerData.citizenid, type = recordType })
    exports.lotb_core:Notify(source, ('Medical record saved: %s'):format(key), 'success')
end, false)
