local config = require 'config.shared'

local function makeKey(prefix)
    return ('%s-%d-%05d'):format(prefix, os.time(), math.random(0, 99999))
end

local function cid(source)
    return exports.lotb_core:GetCitizenId(source)
end

local function targetByKey(key)
    for _, target in ipairs(config.targets) do
        if target.key == key then return target end
    end
end

local function distanceFrom(source, coords)
    local ped = GetPlayerPed(source)
    if not ped or ped <= 0 then return 99999.0 end
    local pos = GetEntityCoords(ped)
    local dx, dy, dz = pos.x - coords.x, pos.y - coords.y, pos.z - coords.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function policeCount()
    local allowed = { police = true, sheriff = true, state = true, bcso = true, sasp = true }
    local count = 0
    for _, playerId in ipairs(GetPlayers()) do
        local player = exports.qbx_core:GetPlayer(tonumber(playerId))
        local job = player and player.PlayerData and player.PlayerData.job
        if job and allowed[job.name] and job.onduty ~= false then count = count + 1 end
    end
    return count
end

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS lotb_robbery_sessions (
          session_key VARCHAR(96) NOT NULL,
          target_key VARCHAR(96) NOT NULL,
          citizenid VARCHAR(64) NOT NULL,
          status VARCHAR(32) NOT NULL DEFAULT 'active',
          stage_index INT NOT NULL DEFAULT 0,
          payout INT NOT NULL DEFAULT 0,
          coords_json LONGTEXT NOT NULL,
          started_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          completed_at DATETIME NULL,
          PRIMARY KEY (session_key),
          KEY idx_lotb_robbery_target (target_key),
          KEY idx_lotb_robbery_citizen (citizenid),
          KEY idx_lotb_robbery_status (status)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
end)

lib.callback.register('lotb_robberies:targets', function()
    local out = {}
    for _, target in ipairs(config.targets) do
        out[#out + 1] = { key = target.key, label = target.label, district = target.district, coords = { x = target.coords.x, y = target.coords.y, z = target.coords.z }, minNetwork = target.minNetwork }
    end
    return out
end)

lib.callback.register('lotb_robberies:start', function(source, targetKey)
    local citizenid = cid(source)
    local target = targetByKey(targetKey)
    if not citizenid or not target then return nil, 'invalid_target' end
    if distanceFrom(source, target.coords) > config.startDistance then return nil, 'too_far' end

    local profile = MySQL.single.await('SELECT network,heat FROM lotb_underworld_profiles WHERE citizenid = ?', { citizenid }) or { network = 0, heat = 0 }
    if (profile.network or 0) < target.minNetwork then return nil, 'not_trusted' end
    if policeCount() < target.minPolice then return nil, 'not_enough_police' end

    local active = MySQL.scalar.await("SELECT 1 FROM lotb_robbery_sessions WHERE citizenid=? AND status='active' LIMIT 1", { citizenid })
    if active then return nil, 'already_active' end

    local cooling = MySQL.scalar.await([[
        SELECT 1 FROM lotb_robbery_sessions
        WHERE target_key = ? AND started_at > DATE_SUB(NOW(), INTERVAL ? MINUTE)
        LIMIT 1
    ]], { target.key, target.cooldownMinutes })
    if cooling then return nil, 'cooldown' end

    local key = makeKey('ROB')
    local payout = math.random(target.payout.min, target.payout.max)
    MySQL.insert.await([[
        INSERT INTO lotb_robbery_sessions (session_key,target_key,citizenid,payout,coords_json)
        VALUES (?,?,?,?,?)
    ]], { key, target.key, citizenid, payout, json.encode({ x = target.coords.x, y = target.coords.y, z = target.coords.z }) })

    local callKey = makeKey('CALL')
    MySQL.insert.await([[
        INSERT INTO lotb_dispatch_calls (call_key,service,caller_citizenid,message,coords_json,status)
        VALUES (?,'911',NULL,?,?, 'open')
    ]], { callKey, ('Automated alarm: suspicious activity at %s.'):format(target.label), json.encode({ x = target.coords.x, y = target.coords.y, z = target.coords.z }) })

    local witnessKey = makeKey('WIT')
    MySQL.insert.await([[
        INSERT INTO lotb_witness_reports (report_key,district,event_type,description_json,confidence,decay_rate,source_kind,expires_at)
        VALUES (?,?, 'suspicious_entry', ?, 58, 3, 'npc', DATE_ADD(NOW(), INTERVAL 12 HOUR))
    ]], { witnessKey, target.district, json.encode({ location = target.label, observation = 'A witness heard forced entry and saw hurried movement near the property.' }) })

    exports.lotb_core:Audit('robbery', source, 'start', key, { target = target.key, dispatch = callKey, witness = witnessKey })
    return { sessionKey = key, targetKey = target.key, label = target.label, district = target.district, coords = { x = target.coords.x, y = target.coords.y, z = target.coords.z }, stages = config.stages }
end)

lib.callback.register('lotb_robberies:advance', function(source, sessionKey, requestedStage)
    local citizenid = cid(source)
    if not citizenid then return false, 'no_character' end
    local session = MySQL.single.await("SELECT * FROM lotb_robbery_sessions WHERE session_key=? AND citizenid=? AND status='active' LIMIT 1", { sessionKey, citizenid })
    if not session then return false, 'invalid_session' end
    local target = targetByKey(session.target_key)
    if not target or distanceFrom(source, target.coords) > config.stageDistance then return false, 'too_far' end

    requestedStage = math.floor(tonumber(requestedStage) or 0)
    if requestedStage ~= (session.stage_index + 1) or not config.stages[requestedStage] then return false, 'bad_stage' end

    if requestedStage < #config.stages then
        MySQL.update.await("UPDATE lotb_robbery_sessions SET stage_index=? WHERE session_key=? AND status='active'", { requestedStage, sessionKey })
        exports.lotb_core:Audit('robbery', source, 'stage', sessionKey, { stage = config.stages[requestedStage].key })
        return true, 'continue'
    end

    local affected = MySQL.update.await("UPDATE lotb_robbery_sessions SET stage_index=?,status='completed',completed_at=NOW() WHERE session_key=? AND status='active'", { requestedStage, sessionKey })
    if not affected or affected < 1 then return false, 'already_finished' end

    local payout = math.max(0, tonumber(session.payout) or 0)
    if payout > 0 then exports.qbx_core:AddMoney(source, 'cash', payout, 'lotb-robbery-proceeds') end

    MySQL.query.await([[
        INSERT INTO lotb_underworld_profiles (citizenid,network,discipline,heat,intel)
        VALUES (?,2,1,6,1)
        ON DUPLICATE KEY UPDATE network=LEAST(100,network+2),discipline=LEAST(100,discipline+1),heat=LEAST(100,heat+6),intel=LEAST(100,intel+1),updated_at=CURRENT_TIMESTAMP
    ]], { citizenid })

    local evidenceKey = makeKey('EV')
    MySQL.insert.await([[
        INSERT INTO lotb_evidence (evidence_key,evidence_type,case_ref,created_by,origin_json,metadata_json,integrity)
        VALUES (?, 'scene_trace', NULL, NULL, ?, ?, ?)
    ]], { evidenceKey, json.encode({ district = target.district, coords = { x = target.coords.x, y = target.coords.y, z = target.coords.z } }), json.encode({ robberySession = sessionKey, target = target.key }), math.random(65, 95) })

    if GetResourceState('lotb_citymemory') == 'started' then
        exports.lotb_citymemory:AddMemory(citizenid, 'underworld_cred', 2, { robbery = target.key, district = target.district })
        exports.lotb_citymemory:AddMemory(citizenid, 'police_attention', 3, { robbery = target.key, district = target.district })
        exports.lotb_citymemory:ChangeDistrict(target.district, { pressure = 4, instability = 2, prosperity = -1 })
    end
    if GetResourceState('lotb_rumors') == 'started' then
        exports.lotb_rumors:SeedRumor({ district = target.district, subject = 'A business got hit', body = ('People are talking about trouble around %s. Nobody agrees on exactly who did it.'):format(target.label), confidence = 52, heat = 35 })
    end

    exports.lotb_core:Audit('robbery', source, 'complete', sessionKey, { target = target.key, payout = payout, evidence = evidenceKey })
    return true, 'completed', payout
end)

RegisterNetEvent('lotb_robberies:abandon', function(sessionKey)
    local source = source
    local citizenid = cid(source)
    if not citizenid then return end
    local session = MySQL.single.await("SELECT * FROM lotb_robbery_sessions WHERE session_key=? AND citizenid=? AND status='active' LIMIT 1", { sessionKey, citizenid })
    if not session then return end
    MySQL.update.await("UPDATE lotb_robbery_sessions SET status='failed',completed_at=NOW() WHERE session_key=? AND status='active'", { sessionKey })
    local target = targetByKey(session.target_key)
    if target and GetResourceState('lotb_citymemory') == 'started' then
        exports.lotb_citymemory:ChangeDistrict(target.district, { pressure = 1, instability = 1 })
    end
    exports.lotb_core:Audit('robbery', source, 'abandon', sessionKey, {})
end)
