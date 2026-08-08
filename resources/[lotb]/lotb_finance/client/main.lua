local function money(n)
    local s = tostring(math.floor(tonumber(n) or 0))
    while true do local k; s,k=s:gsub('^(-?%d+)(%d%d%d)','%1,%2'); if k==0 then break end end
    return s
end

local function businessMenu(business)
    local data = lib.callback.await('lotb_finance:businessLedger', false, business.business_key)
    if not data then return end
    local options = {
        { title = data.name, description = ('Balance $%s • reputation %s • %s'):format(money(data.balance), data.reputation or 0, data.district), icon = 'building' },
        { title = 'Deposit from personal bank', icon = 'arrow-down', onSelect = function()
            local input = lib.inputDialog('Business deposit', {
                { type='number', label='Amount', min=1, required=true }, { type='input', label='Memo', default='owner deposit' }
            })
            if input then TriggerServerEvent('lotb_finance:depositBusiness', data.business_key, input[1], input[2]) end
        end },
        { title = 'Withdraw to personal bank', icon = 'arrow-up', onSelect = function()
            local input = lib.inputDialog('Business withdrawal', {
                { type='number', label='Amount', min=1, required=true }, { type='input', label='Memo', default='owner withdrawal' }
            })
            if input then TriggerServerEvent('lotb_finance:withdrawBusiness', data.business_key, input[1], input[2]) end
        end },
        { title = 'Pay another business', icon = 'money-bill-transfer', onSelect = function()
            local input = lib.inputDialog('Business payment', {
                { type='input', label='Destination business key', required=true }, { type='number', label='Amount', min=1, required=true }, { type='input', label='Memo', default='invoice payment' }
            })
            if input then TriggerServerEvent('lotb_finance:payBusiness', data.business_key, input[1], input[2], input[3]) end
        end }
    }
    for _, row in ipairs(data.ledger or {}) do
        options[#options+1] = {
            title = ('%s $%s'):format(row.direction == 'in' and 'IN' or 'OUT', money(row.amount)),
            description = row.reason or 'Transaction', icon = row.direction == 'in' and 'arrow-trend-up' or 'arrow-trend-down'
        }
    end
    lib.registerContext({ id='lotb_business_bank', title='Business Banking', options=options })
    lib.showContext('lotb_business_bank')
end

RegisterCommand('banking', function()
    local data = lib.callback.await('lotb_finance:overview', false)
    if not data then return end
    local options = {
        { title = ('Personal bank: $%s'):format(money(data.bank)), description = ('Cash: $%s'):format(money(data.cash)), icon='wallet' }
    }

    if (data.pendingTotal or 0) > 0 then
        options[#options+1] = {
            title = ('Pending earnings: $%s'):format(money(data.pendingTotal)),
            description = ('%s payment%s waiting to be collected'):format(#(data.pendingPayouts or {}), #(data.pendingPayouts or {}) == 1 and '' or 's'),
            icon = 'money-check-dollar',
            onSelect = function()
                local rows = {}
                for _, payout in ipairs(data.pendingPayouts or {}) do
                    rows[#rows+1] = {
                        title = ('$%s • %s'):format(money(payout.amount), payout.category),
                        description = payout.reference and ('Reference: ' .. payout.reference) or payout.payout_key,
                        icon = 'hand-holding-dollar',
                        onSelect = function()
                            local confirm = lib.alertDialog({ header = 'Collect payout?', content = ('Deposit $%s to your bank?'):format(money(payout.amount)), cancel = true, centered = true })
                            if confirm == 'confirm' then TriggerServerEvent('lotb_finance:collectPayout', payout.payout_key) end
                        end
                    }
                end
                lib.registerContext({ id='lotb_pending_payouts', title='Pending Earnings', options=rows })
                lib.showContext('lotb_pending_payouts')
            end
        }
    end

    for _, business in ipairs(data.businesses or {}) do
        options[#options+1] = { title=business.name, description=('Business balance: $%s'):format(money(business.balance)), icon='building-columns', onSelect=function() businessMenu(business) end }
    end
    for _, row in ipairs(data.personalLedger or {}) do
        options[#options+1] = { title=('%s $%s'):format(row.direction == 'in' and 'IN' or 'OUT', money(row.amount)), description=row.reason or 'Transaction', icon='receipt' }
    end
    lib.registerContext({ id='lotb_banking', title='LOTB Banking', options=options })
    lib.showContext('lotb_banking')
end, false)
