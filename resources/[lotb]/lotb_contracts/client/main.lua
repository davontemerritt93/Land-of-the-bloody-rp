RegisterCommand('contract', function()
    local input = lib.inputDialog('Create Contract', {
        { type = 'number', label = 'Other Player ID', required = true, min = 1 },
        { type = 'input', label = 'Contract Title', required = true, min = 3, max = 140 },
        { type = 'textarea', label = 'Terms', required = true, min = 10, max = 1000 },
        { type = 'number', label = 'Deal Value', required = false, min = 0, max = 5000000, default = 0 },
        { type = 'number', label = 'Escrow Deposit', description = 'Removed from your bank now and released when you mark an accepted contract complete.', required = false, min = 0, max = 5000000, default = 0 }
    })
    if not input then return end
    TriggerServerEvent('lotb_contracts:create', input[1], input[2], input[3], input[4] or 0, input[5] or 0)
end, false)

RegisterCommand('contractview', function(_, args)
    local key = args[1]
    if not key then return lib.notify({ title = 'Contracts', description = 'Usage: /contractview [key]', type = 'error' }) end
    local row = lib.callback.await('lotb_contracts:get', false, key)
    if not row then return lib.notify({ title = 'Contracts', description = 'Contract not found or access denied.', type = 'error' }) end

    local content = table.concat({
        ('Status: %s'):format(row.status),
        ('Deal value: $%s'):format(row.amount or 0),
        ('Escrow: $%s'):format(row.escrow_amount or 0),
        '',
        row.terms
    }, '\n')

    lib.alertDialog({ header = ('%s — %s'):format(row.contract_key, row.title), content = content, centered = true })
end, false)
