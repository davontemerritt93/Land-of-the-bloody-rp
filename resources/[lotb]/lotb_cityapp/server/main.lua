local function cid(source)
    return exports.lotb_core:GetCitizenId(source)
end

local function makeKey(prefix)
    return ('%s-%d-%05d'):format(prefix, os.time(), math.random(0, 99999))
end

local function qualitativeDistrict(row)
    if not row then return 'The city has no read on this area yet.' end
    local parts = {}
    local pressure = tonumber(row.pressure) or 0
    local prosperity = tonumber(row.prosperity) or 0
    local instability = tonumber(row.instability) or 0
    local pride = tonumber(row.community_pride) or 0
    local trust = tonumber(row.trust) or 0
    if pressure >= 35 then parts[#parts + 1] = 'official attention feels heavy' elseif pressure <= -20 then parts[#parts + 1] = 'official presence feels light' end
    if prosperity >= 30 then parts[#parts + 1] = 'local business activity is strong' elseif prosperity <= -20 then parts[#parts + 1] = 'the local economy looks strained' end
    if instability >= 30 then parts[#parts + 1] = 'people seem uneasy' elseif instability <= -20 then parts[#parts + 1] = 'the area feels unusually settled' end
    if pride >= 30 then parts[#parts + 1] = 'community pride is visible' end
    if trust >= 30 then parts[#parts + 1] = 'neighbors appear more willing to work together' elseif trust <= -25 then parts[#parts + 1] = 'people keep to themselves' end
    if #parts == 0 then return 'The neighborhood feels relatively ordinary right now.' end
    return table.concat(parts, '; ') .. '.'
end

local function homeFeed(source)
    local citizenid = cid(source)
    if not citizenid then return nil end
    local district = Player(source).state.lotbDistrict or 'county'
    local districtRow = MySQL.single.await('SELECT * FROM lotb_district_state WHERE district=?', { district })

    local notices = MySQL.query.await([[
        SELECT feed_key,category,title,body,district,priority,created_at
        FROM lotb_city_services_feed
        WHERE (expires_at IS NULL OR expires_at>NOW()) AND (district IS NULL OR district=? OR district='citywide')
        ORDER BY priority DESC,created_at DESC LIMIT 12
    ]], { district }) or {}

    local archive = MySQL.query.await([[
        SELECT archive_key,title,category,district,summary,event_at,created_at
        FROM lotb_city_archive
        WHERE visibility='public' ORDER BY COALESCE(event_at,created_at) DESC LIMIT 6
    ]]) or {}

    local contracts = MySQL.query.await([[
        SELECT contract_key,title,status,amount,creator_citizenid,counterparty_citizenid,created_at
        FROM lotb_contracts
        WHERE creator_citizenid=? OR counterparty_citizenid=?
        ORDER BY created_at DESC LIMIT 8
    ]], { citizenid, citizenid }) or {}

    local properties = MySQL.query.await([[
        SELECT property_key,label,district,property_type,maintenance,security,owner_citizenid
        FROM lotb_properties
        WHERE owner_citizenid=? OR property_key IN (SELECT property_key FROM lotb_property_access WHERE citizenid=?)
        ORDER BY label LIMIT 10
    ]], { citizenid, citizenid }) or {}

    local businesses = MySQL.query.await([[
        SELECT business_key,name,district,balance,reputation FROM lotb_businesses WHERE owner_citizenid=? ORDER BY name LIMIT 10
    ]], { citizenid }) or {}

    local insurance = MySQL.query.await([[
        SELECT claim_key,policy_key,incident_type,status,requested_amount,approved_amount,created_at
        FROM lotb_insurance_claims WHERE claimant_citizenid=? ORDER BY created_at DESC LIMIT 8
    ]], { citizenid }) or {}

    return {
        citizenid = citizenid,
        district = district,
        districtSummary = qualitativeDistrict(districtRow),
        notices = notices,
        archive = archive,
        contracts = contracts,
        properties = properties,
        businesses = businesses,
        insurance = insurance
    }
end
exports('GetHomeFeed', homeFeed)

lib.callback.register('lotb_cityapp:home', function(source)
    return homeFeed(source)
end)

RegisterNetEvent('lotb_cityapp:publishNotice', function(data)
    local source = source
    if type(data) ~= 'table' then return end
    local groups = exports.qbx_core:GetGroups(source) or {}
    local allowed = exports.lotb_core:HasAce(source, 'lotb.admin') or exports.lotb_core:HasAce(source, 'lotb.justice.manage') or exports.lotb_core:HasAce(source, 'lotb.medical.manage')
        or groups.police ~= nil or groups.sheriff ~= nil or groups.state ~= nil or groups.bcso ~= nil or groups.sasp ~= nil
        or groups.ambulance ~= nil or groups.ems ~= nil or groups.fire ~= nil or groups.doj ~= nil or groups.judge ~= nil
    if not allowed then return end

    local category = exports.lotb_core:CleanText(data.category or 'community', 48)
    local title = exports.lotb_core:CleanText(data.title or '', 140)
    local body = exports.lotb_core:CleanText(data.body or '', 600)
    local district = exports.lotb_core:CleanText(data.district or 'citywide', 64)
    local priority = math.max(0, math.min(10, math.floor(tonumber(data.priority) or 0)))
    local hours = math.max(1, math.min(168, math.floor(tonumber(data.hours) or 24)))
    if title == '' or body == '' then return end

    local key = makeKey('FEED')
    MySQL.insert.await([[
        INSERT INTO lotb_city_services_feed(feed_key,category,title,body,district,priority,expires_at)
        VALUES(?,?,?,?,?,?,DATE_ADD(NOW(),INTERVAL ? HOUR))
    ]], { key, category, title, body, district, priority, hours })
    exports.lotb_core:Audit('cityapp', source, 'publish_notice', key, { category = category, district = district, priority = priority })
    exports.lotb_core:Notify(source, 'City notice published.', 'success')
end)
