local config = require 'config.shared'

local function getPlayer(source)
    return exports.qbx_core:GetPlayer(source)
end
exports('GetPlayer', getPlayer)

local function getCitizenId(source)
    local player = getPlayer(source)
    return player and player.PlayerData and player.PlayerData.citizenid or nil
end
exports('GetCitizenId', getCitizenId)

local function cleanText(value, maxLen)
    if type(value) ~= 'string' then return '' end
    value = value:gsub('[\r\n\t]+', ' '):gsub('%s+', ' ')
    maxLen = tonumber(maxLen) or config.maxText
    return value:sub(1, maxLen)
end
exports('CleanText', cleanText)

local function hasAce(source, permission)
    if source == 0 then return true end
    return IsPlayerAceAllowed(source, permission) == true
end
exports('HasAce', hasAce)

local function audit(category, source, action, target, payload)
    local citizenid = source and source > 0 and getCitizenId(source) or nil
    MySQL.insert.await([[
        INSERT INTO lotb_audit_log (category, actor_citizenid, actor_source, action, target, payload_json)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], {
        cleanText(category, 64), citizenid, source or 0, cleanText(action, 96),
        target and cleanText(tostring(target), 128) or nil,
        json.encode(type(payload) == 'table' and payload or {})
    })
end
exports('Audit', audit)

exports('Notify', function(source, text, kind)
    exports.qbx_core:Notify(source, cleanText(text, 220), kind or 'inform', 5000)
end)

RegisterCommand('lotbhealth', function(source)
    if not hasAce(source, 'lotb.admin') then return end

    local expected = {
        'lotb_core', 'lotb_identity', 'lotb_citymemory', 'lotb_scenethreads', 'lotb_evidence',
        'lotb_economy', 'lotb_businesses', 'lotb_finance', 'lotb_crews', 'lotb_contracts',
        'lotb_dispatch', 'lotb_justice', 'lotb_corrections', 'lotb_medical', 'lotb_world',
        'lotb_rumors', 'lotb_opportunities', 'lotb_archive', 'lotb_media', 'lotb_legacy',
        'lotb_properties', 'lotb_insurance', 'lotb_civicwork', 'lotb_autos', 'lotb_mechanic',
        'lotb_underworld', 'lotb_robberies', 'lotb_tablets', 'lotb_admin', 'lotb_cityapp', 'lotb_hud'
    }

    local failed = {}
    for _, resource in ipairs(expected) do
        local state = GetResourceState(resource)
        if state ~= 'started' and resource ~= GetCurrentResourceName() then
            failed[#failed + 1] = ('%s=%s'):format(resource, state)
        end
    end

    local function tableExists(tableName)
        local ok, result = pcall(function()
            return MySQL.scalar.await([[
                SELECT COUNT(*) FROM information_schema.tables
                WHERE table_schema = DATABASE() AND table_name = ?
            ]], { tableName })
        end)
        return ok and tonumber(result) == 1
    end

    local baseSchemaOk = tableExists('lotb_audit_log')
    local v04SchemaOk = tableExists('lotb_wills')
    local v05SchemaOk = tableExists('lotb_insurance_policies')
        and tableExists('lotb_case_rulings')
        and tableExists('lotb_media_articles')
        and tableExists('lotb_sentences')

    if #failed == 0 and baseSchemaOk and v04SchemaOk and v05SchemaOk then
        return exports.qbx_core:Notify(source, 'LOTB v0.5 health: database ready and all custom resources started.', 'success', 8000)
    end

    local db = ('Database: base=%s v0.4=%s v0.5=%s'):format(
        baseSchemaOk and 'OK' or 'MISSING',
        v04SchemaOk and 'OK' or 'MISSING',
        v05SchemaOk and 'OK' or 'MISSING'
    )
    if #failed > 0 then db = db .. ' | Resources: ' .. table.concat(failed, ', ') end
    exports.qbx_core:Notify(source, db, 'warning', 12000)
end, false)

lib.print.info(('%s core loaded — %s'):format(config.serverName, config.tagline))
