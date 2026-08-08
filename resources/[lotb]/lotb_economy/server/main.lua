local function transferBank(source, target, amount, reason)
    source = tonumber(source)
    target = tonumber(target)
    amount = math.floor(tonumber(amount) or 0)
    if not source or not target or source == target or amount < 1 or amount > 1000000 then return false, 'invalid_transfer' end

    local sender = exports.qbx_core:GetPlayer(source)
    local receiver = exports.qbx_core:GetPlayer(target)
    if not sender or not receiver then return false, 'player_not_found' end

    local balance = exports.qbx_core:GetMoney(source, 'bank')
    if not balance or balance < amount then return false, 'insufficient_funds' end

    local removed = exports.qbx_core:RemoveMoney(source, 'bank', amount, reason or 'LOTB player transfer')
    if not removed then return false, 'debit_failed' end

    local added = exports.qbx_core:AddMoney(target, 'bank', amount, reason or 'LOTB player transfer')
    if not added then
        exports.qbx_core:AddMoney(source, 'bank', amount, 'LOTB transfer rollback')
        return false, 'credit_failed'
    end

    exports.lotb_core:Audit('economy', source, 'bank_transfer', receiver.PlayerData.citizenid, {
        amount = amount,
        reason = exports.lotb_core:CleanText(reason or '', 120)
    })

    return true
end
exports('TransferBank', transferBank)

RegisterNetEvent('lotb_economy:payBank', function(target, amount, reason)
    local source = source
    local ok, err = transferBank(source, target, amount, reason)
    if not ok then
        local messages = {
            invalid_transfer = 'That transfer is not valid.',
            player_not_found = 'That player is not available.',
            insufficient_funds = 'You do not have enough money in the bank.',
            debit_failed = 'The bank could not debit your account.',
            credit_failed = 'The transfer failed and your money was returned.'
        }
        return exports.lotb_core:Notify(source, messages[err] or 'Transfer failed.', 'error')
    end

    exports.lotb_core:Notify(source, 'Bank transfer completed.', 'success')
    exports.lotb_core:Notify(tonumber(target), 'You received a bank transfer.', 'success')
end)
