local config = require 'config.shared'
local lastZone

local function describe(value, positive, negative)
    value = tonumber(value) or 0
    if value >= 40 then return positive end
    if value <= -40 then return negative end
    return nil
end

CreateThread(function()
    while true do
        Wait(5000)
        local coords = GetEntityCoords(cache.ped)
        local zone = GetNameOfZone(coords.x, coords.y, coords.z)
        if zone ~= lastZone then
            lastZone = zone
            TriggerServerEvent('lotb_citymemory:reportDistrict', zone)
        end
    end
end)

RegisterCommand('mymemory', function()
    local profile = lib.callback.await('lotb_citymemory:getProfile', false) or {}
    local lines = {}

    local a = describe(profile.community_trust, 'People tend to trust your name.', 'Some people remember you for the wrong reasons.')
    local b = describe(profile.police_attention, 'Authorities seem unusually aware of you.', 'You rarely draw official attention.')
    local c = describe(profile.underworld_cred, 'Certain underground circles recognize your name.', 'The underground does not take your name seriously.')
    local d = describe(profile.business_reliability, 'Business owners tend to consider you dependable.', 'Your business reputation has taken damage.')

    for _, value in ipairs({ a, b, c, d }) do
        if value then lines[#lines + 1] = value end
    end

    if #lines == 0 then lines[1] = 'The city has not formed a strong opinion about you yet.' end
    lib.alertDialog({ header = 'What the city remembers', content = table.concat(lines, '\n\n'), centered = true })
end, false)

RegisterCommand('citypulse', function()
    local district = LocalPlayer.state.lotbDistrict or 'county'
    local row = lib.callback.await('lotb_citymemory:getDistrict', false, district)
    if not row then return lib.notify({ title = 'City Pulse', description = 'No neighborhood data is available.', type = 'error' }) end

    local lines = { ('Area: %s'):format(row.district) }
    if (row.pressure or 0) >= 35 then lines[#lines + 1] = 'Police pressure feels heavy.' end
    if (row.instability or 0) >= 35 then lines[#lines + 1] = 'People seem tense and unpredictable.' end
    if (row.prosperity or 0) >= 35 then lines[#lines + 1] = 'Local businesses seem to be doing well.' end
    if (row.community_pride or 0) >= 35 then lines[#lines + 1] = 'The neighborhood feels organized and protective of its own.' end
    if (row.trust or 0) <= -35 then lines[#lines + 1] = 'Outsiders are watched closely here.' end
    if #lines == 1 then lines[#lines + 1] = 'Nothing feels unusually different right now.' end

    lib.alertDialog({ header = 'Neighborhood Pulse', content = table.concat(lines, '\n\n'), centered = true })
end, false)
