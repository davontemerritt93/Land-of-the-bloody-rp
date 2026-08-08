local config = require 'config.shared'

local function clamp(value)
    value = math.floor(tonumber(value) or 0)
    return math.max(config.minScore, math.min(config.maxScore, value))
end

local function getCitizenId(source)
    return exports.lotb_core:GetCitizenId(source)
end

local function addMemory(citizenid, memoryType, weight, context)
    if type(citizenid) ~= 'string' or citizenid == '' then return false end
    if type(memoryType) ~= 'string' or memoryType == '' then return false end

    MySQL.insert.await([[
        INSERT INTO lotb_character_memory (citizenid, memory_type, weight, context_json)
        VALUES (?, ?, ?, ?)
    ]], {
        citizenid,
        exports.lotb_core:CleanText(memoryType, 64),
        clamp(weight),
        json.encode(type(context) == 'table' and context or {})
    })

    return true
end
exports('AddMemory', addMemory)

local function changeDistrict(district, delta)
    if type(district) ~= 'string' or district == '' or type(delta) ~= 'table' then return false end

    MySQL.insert.await('INSERT IGNORE INTO lotb_district_state (district) VALUES (?)', { district })
    local row = MySQL.single.await('SELECT * FROM lotb_district_state WHERE district = ?', { district })
    if not row then return false end

    local values = {
        trust = clamp((row.trust or 0) + (tonumber(delta.trust) or 0)),
        pressure = clamp((row.pressure or 0) + (tonumber(delta.pressure) or 0)),
        prosperity = clamp((row.prosperity or 0) + (tonumber(delta.prosperity) or 0)),
        instability = clamp((row.instability or 0) + (tonumber(delta.instability) or 0)),
        community_pride = clamp((row.community_pride or 0) + (tonumber(delta.community_pride) or 0))
    }

    MySQL.update.await([[
        UPDATE lotb_district_state
        SET trust = ?, pressure = ?, prosperity = ?, instability = ?, community_pride = ?
        WHERE district = ?
    ]], { values.trust, values.pressure, values.prosperity, values.instability, values.community_pride, district })

    GlobalState[('lotb:district:%s'):format(district)] = values
    return true, values
end
exports('ChangeDistrict', changeDistrict)

exports('GetDistrict', function(district)
    return MySQL.single.await('SELECT * FROM lotb_district_state WHERE district = ?', { district })
end)

lib.callback.register('lotb_citymemory:getProfile', function(source)
    local citizenid = getCitizenId(source)
    if not citizenid then return {} end

    local rows = MySQL.query.await([[
        SELECT memory_type, SUM(weight) AS score
        FROM lotb_character_memory
        WHERE citizenid = ? AND created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
        GROUP BY memory_type
    ]], { citizenid, config.memoryWindowDays })

    local profile = {}
    for _, row in ipairs(rows or {}) do
        profile[row.memory_type] = tonumber(row.score) or 0
    end
    return profile
end)

lib.callback.register('lotb_citymemory:getDistrict', function(_, district)
    if type(district) ~= 'string' then return nil end
    return MySQL.single.await('SELECT district, trust, pressure, prosperity, instability, community_pride FROM lotb_district_state WHERE district = ?', { district })
end)

RegisterNetEvent('lotb_citymemory:reportDistrict', function(zoneCode)
    local source = source
    if type(zoneCode) ~= 'string' then return end
    local district = config.districts[zoneCode] or 'county'
    Player(source).state:set('lotbDistrict', district, true)
end)

RegisterCommand('lotbmemoryadd', function(source, args)
    if not exports.lotb_core:HasAce(source, 'lotb.admin') then return end
    local target = tonumber(args[1])
    local memoryType = args[2]
    local weight = tonumber(args[3])
    if not target or not memoryType or not weight then
        return exports.lotb_core:Notify(source, 'Usage: /lotbmemoryadd [id] [type] [weight]', 'error')
    end
    local citizenid = getCitizenId(target)
    if not citizenid then return exports.lotb_core:Notify(source, 'Player not found.', 'error') end
    addMemory(citizenid, memoryType, weight, { staff = getCitizenId(source) })
    exports.lotb_core:Audit('memory', source, 'add', citizenid, { type = memoryType, weight = weight })
    exports.lotb_core:Notify(source, 'Memory updated.', 'success')
end, false)

RegisterCommand('lotbdistrict', function(source, args)
    if not exports.lotb_core:HasAce(source, 'lotb.admin') then return end
    local district, field, amount = args[1], args[2], tonumber(args[3])
    local allowed = { trust = true, pressure = true, prosperity = true, instability = true, community_pride = true }
    if not district or not allowed[field] or not amount then
        return exports.lotb_core:Notify(source, 'Usage: /lotbdistrict [district] [field] [amount]', 'error')
    end
    local ok, state = changeDistrict(district, { [field] = amount })
    if ok then
        exports.lotb_core:Audit('district', source, 'change', district, { field = field, amount = amount, state = state })
        exports.lotb_core:Notify(source, 'District state updated.', 'success')
    end
end, false)

CreateThread(function()
    local rows = MySQL.query.await('SELECT district, trust, pressure, prosperity, instability, community_pride FROM lotb_district_state')
    for _, row in ipairs(rows or {}) do
        GlobalState[('lotb:district:%s'):format(row.district)] = {
            trust = row.trust,
            pressure = row.pressure,
            prosperity = row.prosperity,
            instability = row.instability,
            community_pride = row.community_pride
        }
    end
    lib.print.info(('LOTB City Memory loaded %d districts'):format(#(rows or {})))
end)
