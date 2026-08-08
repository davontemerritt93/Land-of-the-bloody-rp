local lastCall

local function openCall(service)
    local input = lib.inputDialog(service, {
        { type = 'textarea', label = 'What is happening?', required = true, min = 3, max = 500 }
    })
    if not input then return end
    TriggerServerEvent('lotb_dispatch:create', service, input[1])
end

RegisterCommand('911', function() openCall('911') end, false)
RegisterCommand('311', function() openCall('311') end, false)

RegisterNetEvent('lotb_dispatch:receive', function(payload)
    if type(payload) ~= 'table' then return end
    lastCall = payload
    lib.notify({
        title = ('Dispatch %s — %s'):format(payload.service or '?', payload.key or '?'),
        description = payload.message or 'No details',
        type = payload.service == '911' and 'warning' or 'inform',
        duration = 9000
    })
end)

RegisterCommand('lastcall', function()
    if not lastCall or not lastCall.coords then
        return lib.notify({ title = 'Dispatch', description = 'No recent call is available.', type = 'error' })
    end
    SetNewWaypoint(lastCall.coords.x + 0.0, lastCall.coords.y + 0.0)
    lib.notify({ title = 'Dispatch', description = ('Waypoint set for %s'):format(lastCall.key or 'call'), type = 'success' })
end, false)
