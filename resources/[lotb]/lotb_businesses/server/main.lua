local function cleanKey(value)
    if type(value) ~= 'string' then return nil end
    value = value:lower():gsub('[^%w_%-]', '')
    if value == '' then return nil end
    return value:sub(1, 96)
end

local function createBusiness(data)
    if type(data) ~= 'table' then return false end
    local key = cleanKey(data.key)
    if not key or type(data.name) ~= 'string' or type(data.ownerCitizenId) ~= 'string' or type(data.district) ~= 'string' then return false end

    MySQL.insert.await([[
        INSERT INTO lotb_businesses (business_key, name, owner_citizenid, district, state_json)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE name = VALUES(name), owner_citizenid = VALUES(owner_citizenid), district = VALUES(district)
    ]], {
        key,
        exports.lotb_core:CleanText(data.name, 140),
        data.ownerCitizenId,
        cleanKey(data.district) or 'downtown',
        json.encode(type(data.state) == 'table' and data.state or {})
    })
    return true
end
exports('CreateBusiness', createBusiness)

exports('AddStock', function(businessKey, itemName, quantity, unitCost)
    businessKey = cleanKey(businessKey)
    itemName = cleanKey(itemName)
    quantity = math.floor(tonumber(quantity) or 0)
    unitCost = math.max(0, math.floor(tonumber(unitCost) or 0))
    if not businessKey or not itemName or quantity == 0 then return false end

    MySQL.insert.await([[
        INSERT INTO lotb_business_stock (business_key, item_name, quantity, unit_cost)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE quantity = GREATEST(0, quantity + VALUES(quantity)), unit_cost = VALUES(unit_cost)
    ]], { businessKey, itemName, quantity, unitCost })
    return true
end)

exports('ConsumeStock', function(businessKey, itemName, quantity)
    businessKey = cleanKey(businessKey)
    itemName = cleanKey(itemName)
    quantity = math.max(1, math.floor(tonumber(quantity) or 0))
    if not businessKey or not itemName then return false end

    local row = MySQL.single.await('SELECT quantity FROM lotb_business_stock WHERE business_key = ? AND item_name = ?', { businessKey, itemName })
    if not row or (row.quantity or 0) < quantity then return false end
    local affected = MySQL.update.await('UPDATE lotb_business_stock SET quantity = quantity - ? WHERE business_key = ? AND item_name = ? AND quantity >= ?', { quantity, businessKey, itemName, quantity })
    return affected and affected > 0
end)

exports('AdjustReputation', function(businessKey, amount)
    amount = math.floor(tonumber(amount) or 0)
    local affected = MySQL.update.await('UPDATE lotb_businesses SET reputation = GREATEST(-100, LEAST(100, reputation + ?)) WHERE business_key = ?', { amount, businessKey })
    return affected and affected > 0
end)

lib.callback.register('lotb_businesses:mine', function(source)
    local citizenid = exports.lotb_core:GetCitizenId(source)
    if not citizenid then return {} end
    local businesses = MySQL.query.await('SELECT business_key, name, district, balance, reputation FROM lotb_businesses WHERE owner_citizenid = ? ORDER BY name', { citizenid }) or {}
    for _, business in ipairs(businesses) do
        business.stock = MySQL.query.await('SELECT item_name, quantity, unit_cost FROM lotb_business_stock WHERE business_key = ? ORDER BY item_name', { business.business_key }) or {}
    end
    return businesses
end)

RegisterCommand('businesscreate', function(source, args)
    if not exports.lotb_core:HasAce(source, 'lotb.business.manage') then return end
    local target = tonumber(args[1])
    local businessKey = args[2]
    local district = args[3]
    local name = table.concat(args, ' ', 4)
    if not target or not businessKey or not district or name == '' then
        return exports.lotb_core:Notify(source, 'Usage: /businesscreate [player-id] [key] [district] [name]', 'error')
    end

    local player = exports.qbx_core:GetPlayer(target)
    if not player then return exports.lotb_core:Notify(source, 'Player not found.', 'error') end
    local ok = createBusiness({ key = businessKey, name = name, ownerCitizenId = player.PlayerData.citizenid, district = district })
    if not ok then return exports.lotb_core:Notify(source, 'Could not create business.', 'error') end

    exports.lotb_core:Audit('business', source, 'create', businessKey, { owner = player.PlayerData.citizenid, district = district })
    exports.lotb_core:Notify(source, 'Business created.', 'success')
    exports.lotb_core:Notify(target, ('You now own %s.'):format(name), 'success')
end, false)
