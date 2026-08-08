local config = require 'config.shared'

local function makeKey(prefix)
    return ('%s-%d-%05d'):format(prefix, os.time(), math.random(0, 99999))
end

local function cid(source)
    return exports.lotb_core:GetCitizenId(source)
end

local function ensureProfile(citizenid)
    MySQL.insert.await('INSERT IGNORE INTO lotb_underworld_profiles (citizenid) VALUES (?)', { citizenid })
    return MySQL.single.await('SELECT * FROM lotb_underworld_profiles WHERE citizenid = ?', { citizenid })
end

local function getOperation(key)
    for _, op in ipairs(config.operations) do
        if op.key == key then return op end
    end
end

lib.callback.register('lotb_underworld:profile', function(source)
    local citizenid = cid(source)
    if not citizenid then return nil end
    return ensureProfile(citizenid)
end)

lib.callback.register('lotb_underworld:activeJob', function(source)
    local citizenid = cid(source)
    if not citizenid then return nil end
    local job = MySQL.single.await([[
        SELECT * FROM lotb_crime_jobs
        WHERE citizenid = ? AND status IN ('offered','active') AND expires_at > NOW()
        ORDER BY created_at DESC LIMIT 1
    ]], { citizenid })
    if job and job.payload_json then job.payload = json.decode(job.payload_json) end
    return job
end)

lib.callback.register('lotb_underworld:requestJob', function(source)
    local citizenid = cid(source)
    if not citizenid then return nil, 'no_character' end
    local profile = ensureProfile(citizenid)

    local existing = MySQL.single.await([[
        SELECT * FROM lotb_crime_jobs
        WHERE citizenid = ? AND status IN ('offered','active') AND expires_at > NOW()
        ORDER BY created_at DESC LIMIT 1
    ]], { citizenid })
    if existing then
        if existing.payload_json then existing.payload = json.decode(existing.payload_json) end
        return existing
    end

    local cooling = MySQL.scalar.await([[
        SELECT 1 FROM lotb_crime_jobs
        WHERE citizenid = ? AND created_at > DATE_SUB(NOW(), INTERVAL ? MINUTE)
        LIMIT 1
    ]], { citizenid, config.operationCooldownMinutes })
    if cooling then return nil, 'cooldown' end

    local eligible = {}
    for _, op in ipairs(config.operations) do
        if (profile.network or 0) >= (op.minNetwork or 0) then eligible[#eligible + 1] = op end
    end
    if #eligible == 0 then return nil, 'no_contacts' end

    local op = eligible[math.random(1, #eligible)]
    local key = makeKey('OP')
    local payout = math.random(op.payout.min, op.payout.max)
    local payload = { operationKey = op.key, label = op.label, coords = { x = op.coords.x, y = op.coords.y, z = op.coords.z }, payout = payout }

    MySQL.insert.await([[
        INSERT INTO lotb_crime_jobs (job_key,citizenid,kind,district,status,difficulty,payload_json,expires_at)
        VALUES (?,?,?,?, 'offered', ?, ?, DATE_ADD(NOW(), INTERVAL 30 MINUTE))
    ]], { key, citizenid, op.kind, op.district, math.max(1, math.floor((op.minNetwork or 0) / 5) + 1), json.encode(payload) })

    exports.lotb_core:Audit('underworld', source, 'offer_operation', key, { operation = op.key, district = op.district })
    return { job_key = key, citizenid = citizenid, kind = op.kind, district = op.district, status = 'offered', difficulty = math.max(1, math.floor((op.minNetwork or 0) / 5) + 1), payload = payload }
end)

RegisterNetEvent('lotb_underworld:acceptJob', function(jobKey)
    local source = source
    local citizenid = cid(source)
    if not citizenid then return end
    local affected = MySQL.update.await([[
        UPDATE lotb_crime_jobs SET status = 'active'
        WHERE job_key = ? AND citizenid = ? AND status = 'offered' AND expires_at > NOW()
    ]], { jobKey, citizenid })
    if affected and affected > 0 then
        exports.lotb_core:Audit('underworld', source, 'accept_operation', jobKey, {})
        exports.lotb_core:Notify(source, 'You took the job. Keep it quiet.', 'success')
    end
end)

RegisterNetEvent('lotb_underworld:completeJob', function(jobKey)
    local source = source
    local citizenid = cid(source)
    if not citizenid then return end
    local job = MySQL.single.await([[
        SELECT * FROM lotb_crime_jobs WHERE job_key = ? AND citizenid = ? AND status = 'active' AND expires_at > NOW() LIMIT 1
    ]], { jobKey, citizenid })
    if not job then return end

    local payload = job.payload_json and json.decode(job.payload_json) or {}
    local op = getOperation(payload.operationKey)
    if not op then return end

    local ped = GetPlayerPed(source)
    if not ped or ped <= 0 then return end
    local pos = GetEntityCoords(ped)
    local dx, dy, dz = pos.x - op.coords.x, pos.y - op.coords.y, pos.z - op.coords.z
    if math.sqrt(dx * dx + dy * dy + dz * dz) > config.completionDistance then
        exports.lotb_core:Audit('underworld', source, 'invalid_completion_distance', jobKey, {})
        return
    end

    local affected = MySQL.update.await("UPDATE lotb_crime_jobs SET status = 'completed' WHERE job_key = ? AND status = 'active'", { jobKey })
    if not affected or affected < 1 then return end

    local payout = math.max(0, math.floor(tonumber(payload.payout) or 0))
    if payout > 0 then exports.qbx_core:AddMoney(source, 'cash', payout, 'lotb-underworld-operation') end
    MySQL.query.await([[
        INSERT INTO lotb_underworld_profiles (citizenid,network,discipline,heat,intel)
        VALUES (?,?,?,?,?)
        ON DUPLICATE KEY UPDATE
          network = LEAST(100, network + VALUES(network)),
          discipline = LEAST(100, discipline + VALUES(discipline)),
          heat = LEAST(100, heat + VALUES(heat)),
          intel = LEAST(100, intel + VALUES(intel)),
          updated_at = CURRENT_TIMESTAMP
    ]], { citizenid, op.network or 0, 1, op.heat or 0, op.intel or 0 })

    if GetResourceState('lotb_citymemory') == 'started' then
        exports.lotb_citymemory:AddMemory(citizenid, 'underworld_cred', math.max(1, op.network or 1), { operation = op.key, district = op.district })
        exports.lotb_citymemory:ChangeDistrict(op.district, { pressure = math.max(0, op.heat or 0), instability = 1 })
    end
    if GetResourceState('lotb_rumors') == 'started' and math.random(1, 100) <= 35 then
        exports.lotb_rumors:SeedRumor({ district = op.district, subject = 'Quiet movement', body = 'People are saying somebody handled a job in the area, but details are thin.', confidence = 35, heat = op.heat or 0 })
    end
    exports.lotb_core:Audit('underworld', source, 'complete_operation', jobKey, { payout = payout, operation = op.key })
    exports.lotb_core:Notify(source, ('Job complete. $%s cash.'):format(payout), 'success')
end)

lib.callback.register('lotb_underworld:recipes', function(source)
    local citizenid = cid(source)
    if not citizenid then return {} end
    local profile = ensureProfile(citizenid)
    return MySQL.query.await([[
        SELECT recipe_key,label,category,requirements_json,outputs_json,minimum_network,minimum_discipline
        FROM lotb_crafting_recipes
        WHERE active = 1 AND minimum_network <= ? AND minimum_discipline <= ?
        ORDER BY category,label
    ]], { profile.network or 0, profile.discipline or 0 }) or {}
end)

RegisterNetEvent('lotb_underworld:craft', function(recipeKey)
    local source = source
    local citizenid = cid(source)
    if not citizenid or type(recipeKey) ~= 'string' then return end
    local profile = ensureProfile(citizenid)
    local recipe = MySQL.single.await('SELECT * FROM lotb_crafting_recipes WHERE recipe_key = ? AND active = 1 LIMIT 1', { recipeKey })
    if not recipe or (profile.network or 0) < recipe.minimum_network or (profile.discipline or 0) < recipe.minimum_discipline then return end

    local requirements = json.decode(recipe.requirements_json or '{}') or {}
    local outputs = json.decode(recipe.outputs_json or '{}') or {}
    for item, count in pairs(requirements) do
        if exports.ox_inventory:GetItemCount(source, item) < count then
            return exports.lotb_core:Notify(source, ('Missing %s x%s.'):format(item, count), 'error')
        end
    end
    for item, count in pairs(outputs) do
        if not exports.ox_inventory:CanCarryItem(source, item, count) then
            return exports.lotb_core:Notify(source, ('No room for %s x%s.'):format(item, count), 'error')
        end
    end

    local removed = {}
    for item, count in pairs(requirements) do
        local success = exports.ox_inventory:RemoveItem(source, item, count)
        if not success then
            for refundItem, refundCount in pairs(removed) do exports.ox_inventory:AddItem(source, refundItem, refundCount) end
            return exports.lotb_core:Notify(source, 'Crafting failed; materials were restored.', 'error')
        end
        removed[item] = count
    end

    for item, count in pairs(outputs) do
        local success = exports.ox_inventory:AddItem(source, item, count)
        if not success then
            for refundItem, refundCount in pairs(removed) do exports.ox_inventory:AddItem(source, refundItem, refundCount) end
            return exports.lotb_core:Notify(source, 'Output item is unavailable; materials were restored.', 'error')
        end
    end

    MySQL.update.await('UPDATE lotb_underworld_profiles SET discipline = LEAST(100, discipline + 1), updated_at = CURRENT_TIMESTAMP WHERE citizenid = ?', { citizenid })
    exports.lotb_core:Audit('underworld', source, 'craft', recipeKey, { requirements = requirements, outputs = outputs })
    exports.lotb_core:Notify(source, ('Crafted %s.'):format(recipe.label), 'success')
end)
