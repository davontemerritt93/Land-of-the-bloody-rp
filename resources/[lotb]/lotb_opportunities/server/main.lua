local templates = {
    supplier = {
        kind = 'business',
        title = 'Local supplier looking for a reliable operator',
        body = 'A business contact is quietly looking for someone dependable to move legitimate stock between local businesses.'
    },
    cleanup = {
        kind = 'community',
        title = 'Neighborhood cleanup needs organizers',
        body = 'Residents are trying to repair damage and restore confidence after recent trouble. They need people who can organize labor and supplies.'
    },
    security = {
        kind = 'business',
        title = 'Businesses want private security planning',
        body = 'Several local owners are discussing coordinated security after a rise in instability. There may be contracts for people with a good reputation.'
    },
    gray = {
        kind = 'underworld',
        title = 'Someone is asking discreet questions',
        body = 'A low-level contact is testing whether anyone trustworthy is available for a risky introduction. Details are intentionally vague.'
    },
    community = {
        kind = 'community',
        title = 'Residents want a neighborhood project',
        body = 'People are talking about funding something permanent for the area. A credible organizer could turn the talk into a real project.'
    }
}

local function makeKey()
    return ('OPP-%d-%05d'):format(os.time(), math.random(0, 99999))
end

local function chooseTemplate(row)
    if (row.instability or 0) >= 45 and (row.pressure or 0) < 60 then return templates.gray end
    if (row.instability or 0) >= 35 then return templates.security end
    if (row.community_pride or 0) <= -20 then return templates.community end
    if (row.prosperity or 0) >= 30 then return templates.supplier end
    return templates.cleanup
end

local function generateForDistrict(district)
    local row = exports.lotb_citymemory:GetDistrict(district)
    if not row then return nil end

    local active = MySQL.scalar.await('SELECT COUNT(*) FROM lotb_opportunities WHERE district = ? AND expires_at > NOW()', { district }) or 0
    if tonumber(active) >= 3 then return nil end

    local template = chooseTemplate(row)
    local key = makeKey()
    MySQL.insert.await([[
        INSERT INTO lotb_opportunities
            (opportunity_key, district, kind, title, body, minimum_heat, maximum_pressure, state_json, expires_at)
        VALUES (?, ?, ?, ?, ?, 0, ?, ?, DATE_ADD(NOW(), INTERVAL 6 HOUR))
    ]], {
        key,
        district,
        template.kind,
        template.title,
        template.body,
        template.kind == 'underworld' and 55 or 100,
        json.encode({ generatedFrom = { pressure = row.pressure, instability = row.instability, prosperity = row.prosperity, community_pride = row.community_pride } })
    })

    exports.lotb_rumors:SeedRumor({
        district = district,
        subject = template.title,
        body = template.body,
        confidence = 55,
        heat = template.kind == 'underworld' and 30 or 5,
        expiresAt = os.date('%Y-%m-%d %H:%M:%S', os.time() + 6 * 60 * 60)
    })

    return key
end
exports('GenerateForDistrict', generateForDistrict)

lib.callback.register('lotb_opportunities:getLocal', function(source)
    local district = Player(source).state.lotbDistrict or 'county'
    local rows = MySQL.query.await([[
        SELECT opportunity_key, kind, title, body, expires_at
        FROM lotb_opportunities
        WHERE district = ? AND expires_at > NOW()
        ORDER BY created_at DESC LIMIT 6
    ]], { district }) or {}
    return { district = district, rows = rows }
end)

RegisterCommand('lotbgenerate', function(source, args)
    if not exports.lotb_core:HasAce(source, 'lotb.admin') then return end
    local district = args[1] or Player(source).state.lotbDistrict or 'county'
    local key = generateForDistrict(district)
    exports.lotb_core:Notify(source, key and ('Generated opportunity: %s'):format(key) or 'No new opportunity was needed.', key and 'success' or 'inform')
end, false)

CreateThread(function()
    Wait(15000)
    while true do
        local districts = MySQL.query.await('SELECT district FROM lotb_district_state') or {}
        for _, row in ipairs(districts) do
            generateForDistrict(row.district)
            Wait(250)
        end
        MySQL.update.await('DELETE FROM lotb_opportunities WHERE expires_at < DATE_SUB(NOW(), INTERVAL 24 HOUR)')
        Wait(30 * 60 * 1000)
    end
end)
