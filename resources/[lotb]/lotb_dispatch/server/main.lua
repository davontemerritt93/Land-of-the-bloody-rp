local function callKey(service)
    return ('%s-%d-%04d'):format(service, os.time(), math.random(0, 9999))
end

local function sendToResponders(service, payload)
    local players = exports.qbx_core:GetQBPlayers()
    for source, player in pairs(players or {}) do
        local job = player.PlayerData and player.PlayerData.job
        local name = job and job.name
        local onDuty = not job or job.onduty ~= false
        local shouldReceive = false

        if service == '911' then
            shouldReceive = onDuty and (name == 'police' or name == 'ambulance')
        elseif service == '311' then
            shouldReceive = onDuty and name == 'police'
        end

        if shouldReceive then
            TriggerClientEvent('lotb_dispatch:receive', source, payload)
        end
    end
end

local function createCall(source, service, message)
    if service ~= '911' and service ~= '311' then return false end
    message = exports.lotb_core:CleanText(message, 500)
    if #message < 3 then return false end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    local coords = GetEntityCoords(ped)
    local citizenid = exports.lotb_core:GetCitizenId(source)
    local key = callKey(service)

    MySQL.insert.await([[
        INSERT INTO lotb_dispatch_calls (call_key, service, caller_citizenid, message, coords_json)
        VALUES (?, ?, ?, ?, ?)
    ]], { key, service, citizenid, message, json.encode({ x = coords.x, y = coords.y, z = coords.z }) })

    local payload = {
        key = key,
        service = service,
        message = message,
        coords = { x = coords.x, y = coords.y, z = coords.z }
    }

    sendToResponders(service, payload)
    exports.lotb_core:Audit('dispatch', source, 'create_call', key, { service = service })
    exports.lotb_core:Notify(source, ('%s call sent. Reference: %s'):format(service, key), 'success')
    return true
end

RegisterNetEvent('lotb_dispatch:create', function(service, message)
    createCall(source, service, message)
end)

exports('CreateCall', createCall)

exports('CloseCall', function(callKey, handledByCitizenId)
    local affected = MySQL.update.await("UPDATE lotb_dispatch_calls SET status = 'closed' WHERE call_key = ? AND status = 'open'", { callKey })
    if affected and affected > 0 then
        exports.lotb_core:Audit('dispatch', 0, 'close_call', callKey, { handledBy = handledByCitizenId })
        return true
    end
    return false
end)
