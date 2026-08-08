RegisterCommand('paybank', function()
    local input = lib.inputDialog('Bank Transfer', {
        { type = 'number', label = 'Player ID', required = true, min = 1 },
        { type = 'number', label = 'Amount', required = true, min = 1, max = 1000000 },
        { type = 'input', label = 'Reason', required = false, max = 120 }
    })
    if not input then return end
    TriggerServerEvent('lotb_economy:payBank', input[1], input[2], input[3] or '')
end, false)
