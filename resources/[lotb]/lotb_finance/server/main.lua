local function cid(source)
    return exports.lotb_core:GetCitizenId(source)
end

local function ownsBusiness(citizenid, businessKey)
    return MySQL.scalar.await('SELECT 1 FROM lotb_businesses WHERE business_key=? AND owner_citizenid=? LIMIT 1', { businessKey, citizenid }) == 1
end

local function ledger(accountType, accountRef, direction, amount, reason, actor)
    MySQL.insert.await([[
        INSERT INTO lotb_bank_ledger (account_type,account_ref,direction,amount,reason,actor_citizenid)
        VALUES (?,?,?,?,?,?)
    ]], { accountType, accountRef, direction, amount, exports.lotb_core:CleanText(reason or '', 180), actor })
end

lib.callback.register('lotb_finance:overview', function(source)
    local citizenid = cid(source)
    if not citizenid then return nil end
    return {
        cash = exports.qbx_core:GetMoney(source, 'cash') or 0,
        bank = exports.qbx_core:GetMoney(source, 'bank') or 0,
        businesses = MySQL.query.await('SELECT business_key,name,balance,reputation,district FROM lotb_businesses WHERE owner_citizenid=? ORDER BY name', { citizenid }) or {},
        personalLedger = MySQL.query.await([[
            SELECT direction,amount,reason,created_at FROM lotb_bank_ledger
            WHERE account_type='player' AND account_ref=? ORDER BY id DESC LIMIT 20
        ]], { citizenid }) or {}
    }
end)

lib.callback.register('lotb_finance:businessLedger', function(source, businessKey)
    local citizenid = cid(source)
    if not citizenid or not ownsBusiness(citizenid, businessKey) then return nil end
    local business = MySQL.single.await('SELECT business_key,name,balance,reputation,district FROM lotb_businesses WHERE business_key=?', { businessKey })
    if not business then return nil end
    business.ledger = MySQL.query.await([[
        SELECT direction,amount,reason,actor_citizenid,created_at FROM lotb_bank_ledger
        WHERE account_type='business' AND account_ref=? ORDER BY id DESC LIMIT 40
    ]], { businessKey }) or {}
    return business
end)

RegisterNetEvent('lotb_finance:depositBusiness', function(businessKey, amount, reason)
    local source = source
    local citizenid = cid(source)
    amount = math.max(1, math.floor(tonumber(amount) or 0))
    if not citizenid or amount > 10000000 or not ownsBusiness(citizenid, businessKey) then return end

    if not exports.qbx_core:RemoveMoney(source, 'bank', amount, 'lotb-business-deposit') then
        return exports.lotb_core:Notify(source, 'Insufficient bank balance.', 'error')
    end
    local affected = MySQL.update.await('UPDATE lotb_businesses SET balance=balance+? WHERE business_key=? AND owner_citizenid=?', { amount, businessKey, citizenid })
    if not affected or affected < 1 then
        exports.qbx_core:AddMoney(source, 'bank', amount, 'lotb-business-deposit-refund')
        return exports.lotb_core:Notify(source, 'Deposit failed; money refunded.', 'error')
    end
    ledger('business', businessKey, 'in', amount, reason ~= '' and reason or 'owner deposit', citizenid)
    ledger('player', citizenid, 'out', amount, 'business deposit: ' .. businessKey, citizenid)
    exports.lotb_core:Audit('finance', source, 'business_deposit', businessKey, { amount = amount })
    exports.lotb_core:Notify(source, ('Deposited $%s into the business.'):format(amount), 'success')
end)

RegisterNetEvent('lotb_finance:withdrawBusiness', function(businessKey, amount, reason)
    local source = source
    local citizenid = cid(source)
    amount = math.max(1, math.floor(tonumber(amount) or 0))
    if not citizenid or amount > 10000000 or not ownsBusiness(citizenid, businessKey) then return end

    local affected = MySQL.update.await('UPDATE lotb_businesses SET balance=balance-? WHERE business_key=? AND owner_citizenid=? AND balance>=?', { amount, businessKey, citizenid, amount })
    if not affected or affected < 1 then return exports.lotb_core:Notify(source, 'Business account has insufficient funds.', 'error') end

    if not exports.qbx_core:AddMoney(source, 'bank', amount, 'lotb-business-withdrawal') then
        MySQL.update.await('UPDATE lotb_businesses SET balance=balance+? WHERE business_key=?', { amount, businessKey })
        return exports.lotb_core:Notify(source, 'Withdrawal failed; business balance restored.', 'error')
    end
    ledger('business', businessKey, 'out', amount, reason ~= '' and reason or 'owner withdrawal', citizenid)
    ledger('player', citizenid, 'in', amount, 'business withdrawal: ' .. businessKey, citizenid)
    exports.lotb_core:Audit('finance', source, 'business_withdrawal', businessKey, { amount = amount })
    exports.lotb_core:Notify(source, ('Withdrew $%s from the business.'):format(amount), 'success')
end)

RegisterNetEvent('lotb_finance:payBusiness', function(fromBusiness, toBusiness, amount, reason)
    local source = source
    local citizenid = cid(source)
    amount = math.max(1, math.floor(tonumber(amount) or 0))
    if not citizenid or amount > 10000000 or fromBusiness == toBusiness or not ownsBusiness(citizenid, fromBusiness) then return end
    local destination = MySQL.scalar.await('SELECT 1 FROM lotb_businesses WHERE business_key=? LIMIT 1', { toBusiness })
    if not destination then return exports.lotb_core:Notify(source, 'Destination business was not found.', 'error') end

    local removed = MySQL.update.await('UPDATE lotb_businesses SET balance=balance-? WHERE business_key=? AND balance>=?', { amount, fromBusiness, amount })
    if not removed or removed < 1 then return exports.lotb_core:Notify(source, 'Business account has insufficient funds.', 'error') end
    local added = MySQL.update.await('UPDATE lotb_businesses SET balance=balance+? WHERE business_key=?', { amount, toBusiness })
    if not added or added < 1 then
        MySQL.update.await('UPDATE lotb_businesses SET balance=balance+? WHERE business_key=?', { amount, fromBusiness })
        return exports.lotb_core:Notify(source, 'Transfer failed; source balance restored.', 'error')
    end
    local memo = reason ~= '' and reason or 'business transfer'
    ledger('business', fromBusiness, 'out', amount, memo .. ' -> ' .. toBusiness, citizenid)
    ledger('business', toBusiness, 'in', amount, memo .. ' <- ' .. fromBusiness, citizenid)
    exports.lotb_core:Audit('finance', source, 'business_transfer', fromBusiness, { to = toBusiness, amount = amount })
    exports.lotb_core:Notify(source, ('Transferred $%s.'):format(amount), 'success')
end)
