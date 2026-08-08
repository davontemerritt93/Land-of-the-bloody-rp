local function makeKey(prefix)
    return ('%s-%d-%05d'):format(prefix, os.time(), math.random(0, 99999))
end

local function cid(source)
    return exports.lotb_core:GetCitizenId(source)
end

lib.callback.register('lotb_autos:listStock', function(_, dealershipKey)
    dealershipKey = exports.lotb_core:CleanText(dealershipKey or 'city_motors', 96)
    return MySQL.query.await([[
        SELECT stock_key,dealership_key,model,label,price,quantity,garage,metadata_json
        FROM lotb_dealership_inventory
        WHERE dealership_key = ? AND quantity > 0
        ORDER BY price,label
    ]], { dealershipKey }) or {}
end)

lib.callback.register('lotb_autos:myVehicles', function(source)
    local citizenid = cid(source)
    if not citizenid then return {} end
    local vehicles = exports.qbx_vehicles:GetPlayerVehicles({ citizenid = citizenid })
    return vehicles or {}
end)

RegisterNetEvent('lotb_autos:buy', function(stockKey)
    local source = source
    local citizenid = cid(source)
    if not citizenid or type(stockKey) ~= 'string' then return end

    local stock = MySQL.single.await('SELECT * FROM lotb_dealership_inventory WHERE stock_key = ? AND quantity > 0 LIMIT 1', { stockKey })
    if not stock then return exports.lotb_core:Notify(source, 'That vehicle is no longer in stock.', 'error') end

    local price = math.max(0, tonumber(stock.price) or 0)
    if price <= 0 then return exports.lotb_core:Notify(source, 'This vehicle cannot be purchased here.', 'error') end

    if not exports.qbx_core:RemoveMoney(source, 'bank', price, 'lotb-vehicle-purchase') then
        return exports.lotb_core:Notify(source, 'You do not have enough money in the bank.', 'error')
    end

    local reserved = MySQL.update.await('UPDATE lotb_dealership_inventory SET quantity = quantity - 1 WHERE stock_key = ? AND quantity > 0', { stockKey })
    if not reserved or reserved < 1 then
        exports.qbx_core:AddMoney(source, 'bank', price, 'lotb-vehicle-stock-refund')
        return exports.lotb_core:Notify(source, 'Someone bought the last one first.', 'error')
    end

    local vehicleId, err = exports.qbx_vehicles:CreatePlayerVehicle({
        model = stock.model,
        citizenid = citizenid,
        garage = stock.garage
    })

    if not vehicleId then
        MySQL.update.await('UPDATE lotb_dealership_inventory SET quantity = quantity + 1 WHERE stock_key = ?', { stockKey })
        exports.qbx_core:AddMoney(source, 'bank', price, 'lotb-vehicle-create-refund')
        exports.lotb_core:Audit('autos', source, 'purchase_failed', stockKey, { error = err })
        return exports.lotb_core:Notify(source, 'The vehicle could not be registered. Your money was refunded.', 'error')
    end

    local saleKey = makeKey('SALE')
    MySQL.insert.await([[
        INSERT INTO lotb_vehicle_sales (sale_key,citizenid,vehicle_id,stock_key,price)
        VALUES (?,?,?,?,?)
    ]], { saleKey, citizenid, vehicleId, stockKey, price })

    MySQL.insert.await([[
        INSERT INTO lotb_bank_ledger (account_type,account_ref,direction,amount,reason,actor_citizenid)
        VALUES ('player',?,'out',?,'vehicle purchase',?)
    ]], { citizenid, price, citizenid })

    exports.lotb_core:Audit('autos', source, 'purchase', tostring(vehicleId), { stock = stockKey, model = stock.model, price = price })
    exports.lotb_core:Notify(source, ('Purchased %s. It is stored at %s.'):format(stock.label, stock.garage), 'success')
end)

RegisterNetEvent('lotb_autos:adminStock', function(data)
    local source = source
    if not exports.lotb_core:HasAce(source, 'lotb.admin') or type(data) ~= 'table' then return end

    local stockKey = exports.lotb_core:CleanText(data.stockKey or makeKey('STOCK'), 96)
    local dealer = exports.lotb_core:CleanText(data.dealershipKey or 'city_motors', 96)
    local model = exports.lotb_core:CleanText(data.model or '', 96)
    local label = exports.lotb_core:CleanText(data.label or model, 140)
    local garage = exports.lotb_core:CleanText(data.garage or 'pillboxgarage', 96)
    local price = math.max(1, math.floor(tonumber(data.price) or 0))
    local quantity = math.max(0, math.floor(tonumber(data.quantity) or 0))
    if model == '' or label == '' then return end

    MySQL.query.await([[
        INSERT INTO lotb_dealership_inventory (stock_key,dealership_key,model,label,price,quantity,garage,metadata_json)
        VALUES (?,?,?,?,?,?,?,?)
        ON DUPLICATE KEY UPDATE dealership_key=VALUES(dealership_key),model=VALUES(model),label=VALUES(label),price=VALUES(price),quantity=VALUES(quantity),garage=VALUES(garage),updated_at=CURRENT_TIMESTAMP
    ]], { stockKey, dealer, model, label, price, quantity, garage, json.encode({}) })

    exports.lotb_core:Audit('autos', source, 'stock_update', stockKey, { dealer = dealer, model = model, price = price, quantity = quantity })
    exports.lotb_core:Notify(source, ('Dealer stock updated: %s'):format(stockKey), 'success')
end)
