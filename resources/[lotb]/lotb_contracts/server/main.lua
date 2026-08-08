local function contractKey()
    return ('CON-%d-%05d'):format(os.time(), math.random(0, 99999))
end

local function notify(source, text, kind)
    exports.lotb_core:Notify(source, text, kind)
end

RegisterNetEvent('lotb_contracts:create', function(targetSource, title, terms, amount, escrow)
    local source = source
    targetSource = tonumber(targetSource)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    escrow = math.max(0, math.floor(tonumber(escrow) or 0))
    if not targetSource or targetSource == source or amount > 5000000 or escrow > 5000000 then return end

    local creator = exports.qbx_core:GetPlayer(source)
    local counterparty = exports.qbx_core:GetPlayer(targetSource)
    if not creator or not counterparty then return notify(source, 'The other player is not available.', 'error') end

    title = exports.lotb_core:CleanText(title, 140)
    terms = exports.lotb_core:CleanText(terms, 1000)
    if #title < 3 or #terms < 10 then return notify(source, 'Add a title and clear contract terms.', 'error') end

    if escrow > 0 then
        local balance = exports.qbx_core:GetMoney(source, 'bank')
        if not balance or balance < escrow then return notify(source, 'You do not have enough bank funds for escrow.', 'error') end
        if not exports.qbx_core:RemoveMoney(source, 'bank', escrow, 'LOTB contract escrow') then
            return notify(source, 'Escrow deposit failed.', 'error')
        end
    end

    local key = contractKey()
    local ok = MySQL.insert.await([[
        INSERT INTO lotb_contracts
            (contract_key, creator_citizenid, counterparty_citizenid, title, terms, amount, escrow_amount, status)
        VALUES (?, ?, ?, ?, ?, ?, ?, 'pending')
    ]], {
        key,
        creator.PlayerData.citizenid,
        counterparty.PlayerData.citizenid,
        title,
        terms,
        amount,
        escrow
    })

    if not ok then
        if escrow > 0 then exports.qbx_core:AddMoney(source, 'bank', escrow, 'LOTB escrow rollback') end
        return notify(source, 'Contract creation failed.', 'error')
    end

    exports.lotb_core:Audit('contract', source, 'create', key, { target = counterparty.PlayerData.citizenid, amount = amount, escrow = escrow })
    notify(source, ('Contract created: %s'):format(key), 'success')
    notify(targetSource, ('You received contract %s. Use /contractview %s'):format(key, key), 'inform')
end)

local function getContract(key)
    return MySQL.single.await('SELECT * FROM lotb_contracts WHERE contract_key = ?', { key })
end

lib.callback.register('lotb_contracts:get', function(source, key)
    if type(key) ~= 'string' then return nil end
    local citizenid = exports.lotb_core:GetCitizenId(source)
    if not citizenid then return nil end
    local row = getContract(key)
    if not row then return nil end
    if row.creator_citizenid ~= citizenid and row.counterparty_citizenid ~= citizenid and not exports.lotb_core:HasAce(source, 'lotb.justice.manage') then return nil end
    return row
end)

RegisterCommand('contractaccept', function(source, args)
    local key = args[1]
    if not key then return notify(source, 'Usage: /contractaccept [key]', 'error') end
    local citizenid = exports.lotb_core:GetCitizenId(source)
    local row = getContract(key)
    if not row or row.counterparty_citizenid ~= citizenid or row.status ~= 'pending' then return notify(source, 'That contract cannot be accepted.', 'error') end

    MySQL.update.await("UPDATE lotb_contracts SET status = 'active', accepted_at = NOW() WHERE contract_key = ? AND status = 'pending'", { key })
    exports.lotb_core:Audit('contract', source, 'accept', key, {})
    notify(source, 'Contract accepted.', 'success')
end, false)

RegisterCommand('contractcomplete', function(source, args)
    local key = args[1]
    if not key then return notify(source, 'Usage: /contractcomplete [key]', 'error') end
    local citizenid = exports.lotb_core:GetCitizenId(source)
    local row = getContract(key)
    if not row or row.creator_citizenid ~= citizenid or row.status ~= 'active' then return notify(source, 'That contract cannot be completed.', 'error') end

    if row.escrow_amount > 0 then
        local receiver = exports.qbx_core:GetPlayerByCitizenId(row.counterparty_citizenid)
        if not receiver then return notify(source, 'Counterparty must be online to release escrow.', 'error') end
        if not exports.qbx_core:AddMoney(receiver.PlayerData.source, 'bank', row.escrow_amount, 'LOTB contract escrow release') then
            return notify(source, 'Escrow release failed.', 'error')
        end
    end

    MySQL.update.await("UPDATE lotb_contracts SET status = 'completed', completed_at = NOW(), escrow_amount = 0 WHERE contract_key = ? AND status = 'active'", { key })
    exports.lotb_core:Audit('contract', source, 'complete', key, { released = row.escrow_amount })
    notify(source, 'Contract completed and escrow released.', 'success')
end, false)

RegisterCommand('contractcancel', function(source, args)
    local key = args[1]
    if not key then return notify(source, 'Usage: /contractcancel [key]', 'error') end
    local citizenid = exports.lotb_core:GetCitizenId(source)
    local row = getContract(key)
    if not row or row.creator_citizenid ~= citizenid or row.status ~= 'pending' then return notify(source, 'Only a pending contract can be cancelled by its creator.', 'error') end

    if row.escrow_amount > 0 then
        if not exports.qbx_core:AddMoney(source, 'bank', row.escrow_amount, 'LOTB contract escrow refund') then
            return notify(source, 'Escrow refund failed.', 'error')
        end
    end

    MySQL.update.await("UPDATE lotb_contracts SET status = 'cancelled', escrow_amount = 0 WHERE contract_key = ? AND status = 'pending'", { key })
    exports.lotb_core:Audit('contract', source, 'cancel', key, { refunded = row.escrow_amount })
    notify(source, 'Contract cancelled and escrow refunded.', 'success')
end, false)
