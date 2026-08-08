local activeJob

local function setActive(job)
    activeJob = job
    if job and job.payload and job.payload.coords then
        local c = job.payload.coords
        SetNewWaypoint(c.x + 0.0, c.y + 0.0)
        lib.notify({ title = 'A quiet job', description = job.payload.label or job.kind, type = 'inform' })
    end
end

local function profileText(p)
    local function band(v)
        v = tonumber(v) or 0
        if v >= 70 then return 'very high' end
        if v >= 40 then return 'established' end
        if v >= 15 then return 'developing' end
        return 'low'
    end
    return ('Connections: %s\nDiscipline: %s\nHeat: %s\nIntel: %s'):format(band(p.network), band(p.discipline), band(p.heat), band(p.intel))
end

RegisterCommand('underworld', function()
    local profile = lib.callback.await('lotb_underworld:profile', false)
    if not profile then return end
    local job = lib.callback.await('lotb_underworld:activeJob', false)
    if job and job.payload_json and not job.payload then job.payload = json.decode(job.payload_json) end
    if job and job.status == 'active' then setActive(job) end

    local options = {
        { title = 'What your contacts think', description = profileText(profile), icon = 'user-secret' }
    }

    if job then
        options[#options + 1] = {
            title = job.payload and job.payload.label or job.kind,
            description = ('Status: %s • %s'):format(job.status, job.district),
            icon = 'location-crosshairs',
            onSelect = function()
                if job.status == 'offered' then
                    TriggerServerEvent('lotb_underworld:acceptJob', job.job_key)
                    job.status = 'active'
                end
                setActive(job)
            end
        }
    else
        options[#options + 1] = {
            title = 'Ask around for work',
            description = 'Your contacts decide what they trust you with.',
            icon = 'comments-dollar',
            onSelect = function()
                local offer, err = lib.callback.await('lotb_underworld:requestJob', false)
                if not offer then
                    local msg = err == 'cooldown' and 'People need time before they call you again.' or 'Nobody has anything for you right now.'
                    return lib.notify({ title = 'No word', description = msg, type = 'inform' })
                end
                local confirm = lib.alertDialog({ header = offer.payload.label, content = ('Area: %s\nTake this job?'):format(offer.district), cancel = true, centered = true })
                if confirm == 'confirm' then
                    TriggerServerEvent('lotb_underworld:acceptJob', offer.job_key)
                    offer.status = 'active'
                    setActive(offer)
                end
            end
        }
    end

    options[#options + 1] = {
        title = 'Known crafting',
        description = 'Recipes appear through relationships and discipline.',
        icon = 'hammer',
        onSelect = function()
            ExecuteCommand('craftknowledge')
        end
    }

    lib.registerContext({ id = 'lotb_underworld', title = 'Your Network', options = options })
    lib.showContext('lotb_underworld')
end, false)

RegisterCommand('craftknowledge', function()
    local rows = lib.callback.await('lotb_underworld:recipes', false) or {}
    local options = {}
    for _, row in ipairs(rows) do
        local req = json.decode(row.requirements_json or '{}') or {}
        local out = json.decode(row.outputs_json or '{}') or {}
        local reqText, outText = {}, {}
        for item, count in pairs(req) do reqText[#reqText + 1] = item .. ' x' .. count end
        for item, count in pairs(out) do outText[#outText + 1] = item .. ' x' .. count end
        options[#options + 1] = {
            title = row.label,
            description = ('Need: %s\nMakes: %s'):format(table.concat(reqText, ', '), table.concat(outText, ', ')),
            icon = 'flask',
            onSelect = function()
                local confirm = lib.alertDialog({ header = row.label, content = 'Use the listed materials?', cancel = true, centered = true })
                if confirm == 'confirm' then TriggerServerEvent('lotb_underworld:craft', row.recipe_key) end
            end
        }
    end
    if #options == 0 then options[1] = { title = 'You do not know any recipes yet.' } end
    lib.registerContext({ id = 'lotb_crafting', title = 'Known Crafting', options = options })
    lib.showContext('lotb_crafting')
end, false)

CreateThread(function()
    Wait(3000)
    local job = lib.callback.await('lotb_underworld:activeJob', false)
    if job and job.payload_json then job.payload = json.decode(job.payload_json) end
    if job and job.status == 'active' then setActive(job) end

    while true do
        local wait = 1500
        if activeJob and activeJob.payload and activeJob.payload.coords then
            local coords = activeJob.payload.coords
            local ped = cache.ped
            local here = GetEntityCoords(ped)
            local dist = #(here - vec3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0))
            if dist < 30.0 then
                wait = 0
                DrawMarker(2, coords.x, coords.y, coords.z + 0.2, 0.0,0.0,0.0, 0.0,180.0,0.0, 0.25,0.25,0.25, 255,255,255,180, false,true,2,false,nil,nil,false)
                if dist < 2.0 then
                    lib.showTextUI('[E] Handle the job')
                    if IsControlJustReleased(0, 38) then
                        lib.hideTextUI()
                        local ok = lib.progressCircle({ duration = 7000, label = 'Keeping your head down...', position = 'bottom', canCancel = true, disable = { move = true, car = true, combat = true } })
                        if ok then
                            TriggerServerEvent('lotb_underworld:completeJob', activeJob.job_key)
                            activeJob = nil
                        end
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
