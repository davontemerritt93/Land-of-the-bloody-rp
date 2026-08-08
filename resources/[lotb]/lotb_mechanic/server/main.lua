local function makeKey(prefix)
    return ('%s-%d-%05d'):format(prefix, os.time(), math.random(0, 99999))
end

local function cid(source)
    return exports.lotb_core:GetCitizenId(source)
end

local function isMechanic(source)
    if exports.lotb_core:HasAce(source, 'lotb.admin') then return true end
    local groups = exports.qbx_core:GetGroups(source) or {}
    return groups.mechanic ~= nil or groups.tuner ~= nil
end

lib.callback.register('lotb_mechanic:myOrders', function(source)
    local citizenid = cid(source)
    if not citizenid then return {} end
    if isMechanic(source) then
        return MySQL.query.await([[
            SELECT * FROM lotb_mechanic_orders
            WHERE status IN ('open','claimed','awaiting_payment','paid')
            ORDER BY created_at DESC LIMIT 30
        ]]) or {}
    end
    return MySQL.query.await([[
        SELECT * FROM lotb_mechanic_orders
        WHERE customer_citizenid = ?
        ORDER BY created_at DESC LIMIT 20
    ]], { citizenid }) or {}
end)

lib.callback.register('lotb_mechanic:history', function(_, vehicleId)
    vehicleId = math.floor(tonumber(vehicleId) or 0)
    if vehicleId <= 0 then return {} end
    return MySQL.query.await([[
        SELECT service_type,summary,mileage,mechanic_citizenid,created_at
        FROM lotb_vehicle_service_history WHERE vehicle_id = ? ORDER BY id DESC LIMIT 25
    ]], { vehicleId }) or {}
end)

RegisterNetEvent('lotb_mechanic:createOrder', function(data)
    local source = source
    local citizenid = cid(source)
    if not citizenid or type(data) ~= 'table' then return end
    local vehicleId = math.floor(tonumber(data.vehicleId) or 0)
    local description = exports.lotb_core:CleanText(data.description or '', 800)
    if vehicleId <= 0 or description == '' then return end

    local vehicle = exports.qbx_vehicles:GetPlayerVehicle(vehicleId, { citizenid = citizenid })
    if not vehicle then return exports.lotb_core:Notify(source, 'That vehicle is not registered to you.', 'error') end

    local key = makeKey('WORK')
    MySQL.insert.await([[
        INSERT INTO lotb_mechanic_orders (order_key,vehicle_id,customer_citizenid,description)
        VALUES (?,?,?,?)
    ]], { key, vehicleId, citizenid, description })
    exports.lotb_core:Audit('mechanic', source, 'create_order', key, { vehicleId = vehicleId })
    exports.lotb_core:Notify(source, ('Work order opened: %s'):format(key), 'success')
end)

RegisterNetEvent('lotb_mechanic:claim', function(orderKey)
    local source = source
    if not isMechanic(source) then return end
    local mechanicCid = cid(source)
    local affected = MySQL.update.await([[
        UPDATE lotb_mechanic_orders SET mechanic_citizenid = ?, status = 'claimed'
        WHERE order_key = ? AND status = 'open'
    ]], { mechanicCid, orderKey })
    if affected and affected > 0 then
        exports.lotb_core:Audit('mechanic', source, 'claim_order', orderKey, {})
        exports.lotb_core:Notify(source, 'Work order claimed.', 'success')
    end
end)

RegisterNetEvent('lotb_mechanic:quote', function(orderKey, amount)
    local source = source
    if not isMechanic(source) then return end
    local mechanicCid = cid(source)
    amount = math.max(0, math.min(250000, math.floor(tonumber(amount) or 0)))
    local affected = MySQL.update.await([[
        UPDATE lotb_mechanic_orders SET quoted_price = ?, status = 'awaiting_payment'
        WHERE order_key = ? AND mechanic_citizenid = ? AND status IN ('claimed','awaiting_payment')
    ]], { amount, orderKey, mechanicCid })
    if affected and affected > 0 then
        exports.lotb_core:Audit('mechanic', source, 'quote_order', orderKey, { amount = amount })
        exports.lotb_core:Notify(source, ('Quote set to $%s.'):format(amount), 'success')
    end
end)

RegisterNetEvent('lotb_mechanic:payOrder', function(orderKey)
    local source = source
    local citizenid = cid(source)
    if not citizenid then return end

    local order = MySQL.single.await([[
        SELECT * FROM lotb_mechanic_orders WHERE order_key = ? AND customer_citizenid = ? LIMIT 1
    ]], { orderKey, citizenid })
    if not order or order.status ~= 'awaiting_payment' or not order.mechanic_citizenid then return end

    local amount = math.max(0, tonumber(order.quoted_price) or 0)
    local locked = MySQL.update.await([[
        UPDATE lotb_mechanic_orders SET status = 'payment_processing'
        WHERE order_key = ? AND customer_citizenid = ? AND status = 'awaiting_payment'
    ]], { orderKey, citizenid })
    if not locked or locked < 1 then return end

    if amount > 0 and not exports.qbx_core:RemoveMoney(source, 'bank', amount, 'lotb-mechanic-work') then
        MySQL.update.await("UPDATE lotb_mechanic_orders SET status='awaiting_payment' WHERE order_key=? AND status='payment_processing'", { orderKey })
        return exports.lotb_core:Notify(source, 'You cannot afford the repair quote.', 'error')
    end

    local payoutKey
    if amount > 0 then
        local ok, result = pcall(function()
            return exports.lotb_finance:CreatePendingPayout(order.mechanic_citizenid, amount, 'mechanic', orderKey)
        end)
        payoutKey = ok and result or nil
        if not payoutKey then
            exports.qbx_core:AddMoney(source, 'bank', amount, 'lotb-mechanic-payment-refund')
            MySQL.update.await("UPDATE lotb_mechanic_orders SET status='awaiting_payment' WHERE order_key=? AND status='payment_processing'", { orderKey })
            exports.lotb_core:Audit('mechanic', source, 'payment_payout_failed', orderKey, { amount = amount })
            return exports.lotb_core:Notify(source, 'Payment could not be routed; your money was refunded.', 'error')
        end
    end

    MySQL.update.await([[
        UPDATE lotb_mechanic_orders SET paid_amount = ?, status = 'paid'
        WHERE order_key = ? AND status = 'payment_processing'
    ]], { amount, orderKey })
    MySQL.insert.await([[
        INSERT INTO lotb_bank_ledger (account_type,account_ref,direction,amount,reason,actor_citizenid)
        VALUES ('player',?,'out',?,'mechanic work',?)
    ]], { citizenid, amount, citizenid })
    exports.lotb_core:Audit('mechanic', source, 'pay_order', orderKey, { amount = amount, mechanic = order.mechanic_citizenid, payout = payoutKey })
    exports.lotb_core:Notify(source, 'Repair quote paid.', 'success')
end)

RegisterNetEvent('lotb_mechanic:complete', function(orderKey, serviceType, summary, mileage)
    local source = source
    if not isMechanic(source) then return end
    local mechanicCid = cid(source)
    serviceType = exports.lotb_core:CleanText(serviceType or 'repair', 64)
    summary = exports.lotb_core:CleanText(summary or '', 500)
    mileage = math.max(0, math.floor(tonumber(mileage) or 0))
    local order = MySQL.single.await([[
        SELECT * FROM lotb_mechanic_orders WHERE order_key = ? AND mechanic_citizenid = ? LIMIT 1
    ]], { orderKey, mechanicCid })
    if not order or order.status ~= 'paid' or summary == '' then return end

    MySQL.insert.await([[
        INSERT INTO lotb_vehicle_service_history (vehicle_id,order_key,service_type,summary,mileage,mechanic_citizenid)
        VALUES (?,?,?,?,?,?)
    ]], { order.vehicle_id, orderKey, serviceType, summary, mileage > 0 and mileage or nil, mechanicCid })
    MySQL.update.await("UPDATE lotb_mechanic_orders SET status = 'completed', completed_at = NOW() WHERE order_key = ? AND status='paid'", { orderKey })
    exports.lotb_core:Audit('mechanic', source, 'complete_order', orderKey, { vehicleId = order.vehicle_id, type = serviceType })
    exports.lotb_core:Notify(source, 'Work order completed and service history saved.', 'success')
end)
