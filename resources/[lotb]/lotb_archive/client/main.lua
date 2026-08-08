local scars = {}

local function refreshScars()
    scars = lib.callback.await('lotb_archive:scars', false) or {}
end

local function drawText3D(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.28, 0.28)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(245, 245, 245, 210)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end

CreateThread(function()
    Wait(5000)
    refreshScars()
    while true do
        local sleep = 1000
        local coords = GetEntityCoords(cache.ped)
        for _, scar in ipairs(scars) do
            if scar.coords then
                local pos = vector3(scar.coords.x + 0.0, scar.coords.y + 0.0, scar.coords.z + 0.0)
                local distance = #(coords - pos)
                if distance < 35.0 then
                    sleep = 0
                    if distance < 18.0 then
                        drawText3D(pos.x, pos.y, pos.z + 0.35, ('[%s] %s'):format(scar.kind, scar.label))
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        Wait(60000)
        refreshScars()
    end
end)

RegisterNetEvent('lotb_archive:refreshScars', refreshScars)

RegisterCommand('archive', function()
    local rows = lib.callback.await('lotb_archive:list', false) or {}
    if #rows == 0 then return lib.notify({ title = 'City Archive', description = 'The public archive is empty.', type = 'inform' }) end
    local options = {}
    for _, row in ipairs(rows) do
        options[#options + 1] = {
            title = row.title,
            description = ('%s\n%s'):format(row.district or row.category, row.summary),
            icon = 'landmark'
        }
    end
    lib.registerContext({ id = 'lotb_archive_ctx', title = 'Land of the Bloody — City Archive', options = options })
    lib.showContext('lotb_archive_ctx')
end, false)

RegisterCommand('archiveadd', function()
    local input = lib.inputDialog('Add City History', {
        { type = 'input', label = 'Category', required = true, max = 64, default = 'city' },
        { type = 'input', label = 'Headline', required = true, min = 3, max = 160 },
        { type = 'textarea', label = 'What happened?', required = true, min = 10, max = 1000 }
    })
    if not input then return end
    TriggerServerEvent('lotb_archive:addEntry', input[1], input[2], input[3])
end, false)

RegisterCommand('scaradd', function()
    local input = lib.inputDialog('Create World Scar', {
        { type = 'select', label = 'Type', required = true, options = {
            { value = 'memorial', label = 'Memorial' },
            { value = 'fire_damage', label = 'Fire Damage' },
            { value = 'crime_scene', label = 'Aftermath / Crime Scene' },
            { value = 'community_project', label = 'Community Project' },
            { value = 'construction', label = 'Construction / Repair' }
        } },
        { type = 'input', label = 'What players see', required = true, min = 3, max = 220 },
        { type = 'number', label = 'Lifetime in hours', description = '0 = permanent until removed manually.', required = true, min = 0, max = 720, default = 24 }
    })
    if not input then return end
    TriggerServerEvent('lotb_archive:addScar', input[1], input[2], input[3])
end, false)
