local function makeKey(prefix)
    return ('%s-%d-%05d'):format(prefix, os.time(), math.random(0, 99999))
end

local function cid(source)
    return exports.lotb_core:GetCitizenId(source)
end

local function owns(citizenid, propertyKey)
    return MySQL.scalar.await('SELECT 1 FROM lotb_properties WHERE property_key = ? AND owner_citizenid = ? LIMIT 1', { propertyKey, citizenid }) == 1
end

local function canAccess(citizenid, propertyKey)
    if owns(citizenid, propertyKey) then return true end
    return MySQL.scalar.await('SELECT 1 FROM lotb_property_access WHERE property_key = ? AND citizenid = ? LIMIT 1', { propertyKey, citizenid }) == 1
end
exports('CanAccess', canAccess)

lib.callback.register('lotb_properties:listMine', function(source)
    local citizenid = cid(source)
    if not citizenid then return {} end
    local rows = MySQL.query.await([[
        SELECT p.property_key,p.label,p.district,p.property_type,p.owner_citizenid,p.purchase_price,p.rent_price,p.maintenance,p.security,p.coords_json,p.state_json,
               (SELECT a.access_level FROM lotb_property_access a WHERE a.property_key=p.property_key AND a.citizenid=? LIMIT 1) AS access_level
        FROM lotb_properties p
        WHERE p.owner_citizenid = ? OR p.property_key IN (SELECT property_key FROM lotb_property_access WHERE citizenid = ?)
        ORDER BY p.label
    ]], { citizenid, citizenid, citizenid }) or {}
    for _, row in ipairs(rows) do
        row.isOwner = row.owner_citizenid == citizenid
        row.isOwned = row.owner_citizenid ~= nil
        row.owner_citizenid = nil
    end
    return rows
end)

lib.callback.register('lotb_properties:nearby', function(source)
    local citizenid = cid(source)
    local ped = GetPlayerPed(source)
    if not citizenid or not ped or ped <= 0 then return {} end
    local pos = GetEntityCoords(ped)
    local rows = MySQL.query.await('SELECT property_key,label,district,property_type,owner_citizenid,purchase_price,rent_price,maintenance,security,coords_json FROM lotb_properties') or {}
    local out = {}
    for _, row in ipairs(rows) do
        local coords = row.coords_json and json.decode(row.coords_json) or nil
        if coords and coords.x and coords.y and coords.z then
            local dx, dy, dz = pos.x - coords.x, pos.y - coords.y, pos.z - coords.z
            local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
            if distance <= 30.0 then
                row.distance = math.floor(distance * 10) / 10
                row.isOwner = row.owner_citizenid == citizenid
                row.isOwned = row.owner_citizenid ~= nil
                row.owner_citizenid = nil
                out[#out + 1] = row
            end
        end
    end
    table.sort(out, function(a, b) return (a.distance or 999) < (b.distance or 999) end)
    return out
end)

RegisterNetEvent('lotb_properties:buy', function(propertyKey)
    local source = source
    local citizenid = cid(source)
    if not citizenid or type(propertyKey) ~= 'string' then return end

    local property = MySQL.single.await('SELECT * FROM lotb_properties WHERE property_key = ? LIMIT 1', { propertyKey })
    if not property or property.owner_citizenid then return exports.lotb_core:Notify(source, 'That property is not available.', 'error') end

    local price = math.max(0, tonumber(property.purchase_price) or 0)
    if price <= 0 then return exports.lotb_core:Notify(source, 'This property is not for public sale.', 'error') end
    if not exports.qbx_core:RemoveMoney(source, 'bank', price, 'lotb-property-purchase') then
        return exports.lotb_core:Notify(source, 'You do not have enough money in the bank.', 'error')
    end

    local affected = MySQL.update.await('UPDATE lotb_properties SET owner_citizenid = ? WHERE property_key = ? AND owner_citizenid IS NULL', { citizenid, propertyKey })
    if not affected or affected < 1 then
        exports.qbx_core:AddMoney(source, 'bank', price, 'lotb-property-refund')
        return exports.lotb_core:Notify(source, 'The property was purchased by someone else.', 'error')
    end

    MySQL.insert.await('INSERT IGNORE INTO lotb_property_access (property_key,citizenid,access_level,granted_by) VALUES (?,?,?,?)', { propertyKey, citizenid, 'owner', citizenid })
    exports.lotb_core:Audit('property', source, 'purchase', propertyKey, { price = price, district = property.district })
    if GetResourceState('lotb_citymemory') == 'started' then
        exports.lotb_citymemory:ChangeDistrict(property.district, { prosperity = 1, community_pride = 1 })
    end
    exports.lotb_core:Notify(source, ('You purchased %s.'):format(property.label), 'success')
end)

RegisterNetEvent('lotb_properties:grantAccess', function(propertyKey, targetCitizenId, accessLevel)
    local source = source
    local citizenid = cid(source)
    if not citizenid or not owns(citizenid, propertyKey) then return end
    targetCitizenId = exports.lotb_core:CleanText(targetCitizenId or '', 64)
    accessLevel = exports.lotb_core:CleanText(accessLevel or 'guest', 32)
    if targetCitizenId == '' then return end

    MySQL.query.await([[
        INSERT INTO lotb_property_access (property_key,citizenid,access_level,granted_by)
        VALUES (?,?,?,?)
        ON DUPLICATE KEY UPDATE access_level = VALUES(access_level), granted_by = VALUES(granted_by)
    ]], { propertyKey, targetCitizenId, accessLevel, citizenid })
    exports.lotb_core:Audit('property', source, 'grant_access', propertyKey, { target = targetCitizenId, level = accessLevel })
    exports.lotb_core:Notify(source, 'Property access updated.', 'success')
end)

RegisterNetEvent('lotb_properties:revokeAccess', function(propertyKey, targetCitizenId)
    local source = source
    local citizenid = cid(source)
    if not citizenid or not owns(citizenid, propertyKey) then return end
    targetCitizenId = exports.lotb_core:CleanText(targetCitizenId or '', 64)
    if targetCitizenId == '' or targetCitizenId == citizenid then return end
    MySQL.update.await('DELETE FROM lotb_property_access WHERE property_key = ? AND citizenid = ?', { propertyKey, targetCitizenId })
    exports.lotb_core:Audit('property', source, 'revoke_access', propertyKey, { target = targetCitizenId })
    exports.lotb_core:Notify(source, 'Property access removed.', 'success')
end)

RegisterNetEvent('lotb_properties:maintain', function(propertyKey, amount)
    local source = source
    local citizenid = cid(source)
    if not citizenid or not owns(citizenid, propertyKey) then return end
    amount = math.max(1, math.min(25, math.floor(tonumber(amount) or 0)))
    local property = MySQL.single.await('SELECT maintenance,district FROM lotb_properties WHERE property_key = ?', { propertyKey })
    if not property then return end
    local price = amount * 150
    if not exports.qbx_core:RemoveMoney(source, 'bank', price, 'lotb-property-maintenance') then
        return exports.lotb_core:Notify(source, 'You cannot afford that maintenance.', 'error')
    end
    MySQL.update.await('UPDATE lotb_properties SET maintenance = LEAST(100, maintenance + ?) WHERE property_key = ?', { amount, propertyKey })
    exports.lotb_core:Audit('property', source, 'maintenance', propertyKey, { points = amount, price = price })
    if GetResourceState('lotb_citymemory') == 'started' then
        exports.lotb_citymemory:ChangeDistrict(property.district, { community_pride = math.max(1, math.floor(amount / 10)) })
    end
    exports.lotb_core:Notify(source, 'Property maintenance completed.', 'success')
end)

RegisterNetEvent('lotb_properties:createAdmin', function(data)
    local source = source
    if not exports.lotb_core:HasAce(source, 'lotb.admin') or type(data) ~= 'table' then return end
    local label = exports.lotb_core:CleanText(data.label or '', 140)
    local district = exports.lotb_core:CleanText(data.district or 'downtown', 64)
    local kind = exports.lotb_core:CleanText(data.propertyType or 'residential', 48)
    local price = math.max(0, math.floor(tonumber(data.price) or 0))
    local coords = data.coords
    if label == '' or type(coords) ~= 'table' then return end
    local key = makeKey('PROP')
    MySQL.insert.await([[
        INSERT INTO lotb_properties (property_key,label,district,property_type,purchase_price,coords_json,state_json)
        VALUES (?,?,?,?,?,?,?)
    ]], { key, label, district, kind, price, json.encode(coords), json.encode({}) })
    exports.lotb_core:Audit('property', source, 'admin_create', key, { label = label, district = district, price = price })
    exports.lotb_core:Notify(source, ('Property created: %s'):format(key), 'success')
end)

CreateThread(function()
    while true do
        Wait(6 * 60 * 60 * 1000)
        MySQL.update.await('UPDATE lotb_properties SET maintenance = GREATEST(0, maintenance - 1) WHERE owner_citizenid IS NOT NULL')
    end
end)
