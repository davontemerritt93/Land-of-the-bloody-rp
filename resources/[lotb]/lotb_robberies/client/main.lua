local config = require 'config.shared'
local running = false

local function nearestTarget()
    local here = GetEntityCoords(cache.ped)
    local best, bestDistance
    for _, target in ipairs(config.targets) do
        local distance = #(here - target.coords)
        if not bestDistance or distance < bestDistance then
            best, bestDistance = target, distance
        end
    end
    return best, bestDistance or 99999.0
end

local errors = {
    invalid_target = 'Nothing here can be hit right now.',
    too_far = 'Get closer to the location.',
    not_trusted = 'Your network does not trust you with this yet.',
    not_enough_police = 'The city is too quiet for this opportunity.',
    already_active = 'Finish what you already started.',
    cooldown = 'This place is still too hot.'
}

RegisterCommand('robbery', function()
    if running then return end
    local target, distance = nearestTarget()
    if not target or distance > config.startDistance then
        return lib.notify({ title = 'Opportunity', description = 'Nothing here looks workable.', type = 'inform' })
    end

    local confirm = lib.alertDialog({
        header = target.label,
        content = 'Start this scene? Once you begin, alarms, witnesses and evidence can exist even if you walk away.',
        cancel = true,
        centered = true
    })
    if confirm ~= 'confirm' then return end

    local session, err = lib.callback.await('lotb_robberies:start', false, target.key)
    if not session then return lib.notify({ title = 'Opportunity', description = errors[err] or 'The opportunity fell through.', type = 'error' }) end

    running = true
    for index, stage in ipairs(session.stages or config.stages) do
        local ok = lib.progressCircle({
            duration = stage.duration,
            label = stage.label,
            position = 'bottom',
            canCancel = true,
            disable = { move = true, car = true, combat = true, sprint = true }
        })
        if not ok then
            TriggerServerEvent('lotb_robberies:abandon', session.sessionKey)
            running = false
            return lib.notify({ title = 'Scene abandoned', description = 'Walking away does not erase what already happened.', type = 'warning' })
        end

        local advanced, state, payout = lib.callback.await('lotb_robberies:advance', false, session.sessionKey, index)
        if not advanced then
            TriggerServerEvent('lotb_robberies:abandon', session.sessionKey)
            running = false
            return lib.notify({ title = 'Scene failed', description = 'The situation changed before you finished.', type = 'error' })
        end
        if state == 'completed' then
            running = false
            return lib.notify({ title = 'Scene complete', description = ('$%s recovered. The city may remember more than you think.'):format(payout or 0), type = 'success' })
        end
    end
    running = false
end, false)

CreateThread(function()
    while true do
        local wait = 1200
        if not running then
            local target, distance = nearestTarget()
            if target and distance < 15.0 then
                wait = 0
                DrawMarker(2, target.coords.x, target.coords.y, target.coords.z + 0.15, 0.0,0.0,0.0, 0.0,180.0,0.0, 0.18,0.18,0.18, 255,255,255,120, false,true,2,false,nil,nil,false)
                if distance < 2.2 then
                    lib.showTextUI('[E] Read the situation')
                    if IsControlJustReleased(0, 38) then
                        lib.hideTextUI()
                        ExecuteCommand('robbery')
                    end
                else
                    lib.hideTextUI()
                end
            else
                lib.hideTextUI()
            end
        else
            lib.hideTextUI()
        end
        Wait(wait)
    end
end)
