local function cleanKey(value)
    if type(value) ~= 'string' then return nil end
    value = value:lower():gsub('[^%w_%-]', '')
    return value ~= '' and value:sub(1, 96) or nil
end

local function adjust(crewKey, heatDelta, influenceDelta)
    crewKey = cleanKey(crewKey)
    if not crewKey then return false end
    heatDelta = math.floor(tonumber(heatDelta) or 0)
    influenceDelta = math.floor(tonumber(influenceDelta) or 0)
    local affected = MySQL.update.await([[
        UPDATE lotb_crews
        SET heat = GREATEST(0, LEAST(100, heat + ?)),
            influence = GREATEST(-100, LEAST(100, influence + ?))
        WHERE crew_key = ?
    ]], { heatDelta, influenceDelta, crewKey })
    return affected and affected > 0
end
exports('AdjustStanding', adjust)

exports('GetCrewForCitizen', function(citizenid)
    return MySQL.single.await([[
        SELECT c.crew_key, c.name, c.heat, c.influence, m.rank_name
        FROM lotb_crew_members m JOIN lotb_crews c ON c.crew_key = m.crew_key
        WHERE m.citizenid = ? LIMIT 1
    ]], { citizenid })
end)

lib.callback.register('lotb_crews:mine', function(source)
    local citizenid = exports.lotb_core:GetCitizenId(source)
    if not citizenid then return nil end
    return MySQL.single.await([[
        SELECT c.crew_key, c.name, c.heat, c.influence, m.rank_name
        FROM lotb_crew_members m JOIN lotb_crews c ON c.crew_key = m.crew_key
        WHERE m.citizenid = ? LIMIT 1
    ]], { citizenid })
end)

RegisterCommand('crewcreate', function(source, args)
    if not exports.lotb_core:HasAce(source, 'lotb.crew.manage') then return end
    local target = tonumber(args[1])
    local crewKey = cleanKey(args[2])
    local name = table.concat(args, ' ', 3)
    if not target or not crewKey or name == '' then
        return exports.lotb_core:Notify(source, 'Usage: /crewcreate [leader-id] [key] [name]', 'error')
    end
    local player = exports.qbx_core:GetPlayer(target)
    if not player then return exports.lotb_core:Notify(source, 'Player not found.', 'error') end
    local citizenid = player.PlayerData.citizenid

    MySQL.insert.await([[
        INSERT INTO lotb_crews (crew_key, name, leader_citizenid)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE name = VALUES(name), leader_citizenid = VALUES(leader_citizenid)
    ]], { crewKey, exports.lotb_core:CleanText(name, 120), citizenid })
    MySQL.insert.await([[
        INSERT INTO lotb_crew_members (crew_key, citizenid, rank_name)
        VALUES (?, ?, 'leader')
        ON DUPLICATE KEY UPDATE rank_name = 'leader'
    ]], { crewKey, citizenid })

    exports.lotb_core:Audit('crew', source, 'create', crewKey, { leader = citizenid })
    exports.lotb_core:Notify(source, 'Crew created.', 'success')
    exports.lotb_core:Notify(target, ('You are now leading %s.'):format(name), 'success')
end, false)

RegisterCommand('crewadd', function(source, args)
    if not exports.lotb_core:HasAce(source, 'lotb.crew.manage') then return end
    local crewKey = cleanKey(args[1])
    local target = tonumber(args[2])
    local rank = exports.lotb_core:CleanText(args[3] or 'member', 64)
    local player = target and exports.qbx_core:GetPlayer(target) or nil
    if not crewKey or not player then return exports.lotb_core:Notify(source, 'Usage: /crewadd [crew-key] [player-id] [rank]', 'error') end
    MySQL.insert.await([[
        INSERT INTO lotb_crew_members (crew_key, citizenid, rank_name)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE rank_name = VALUES(rank_name)
    ]], { crewKey, player.PlayerData.citizenid, rank })
    exports.lotb_core:Audit('crew', source, 'add_member', crewKey, { citizenid = player.PlayerData.citizenid, rank = rank })
    exports.lotb_core:Notify(source, 'Crew member updated.', 'success')
end, false)
