local function money(n)
    local s = tostring(math.floor(tonumber(n) or 0))
    while true do
        local k
        s, k = s:gsub('^(-?%d+)(%d%d%d)', '%1,%2')
        if k == 0 then break end
    end
    return s
end

RegisterCommand('dealer', function(_, args)
    local dealership = args[1] or 'city_motors'
    local rows = lib.callback.await('lotb_autos:listStock', false, dealership) or {}
    local options = {}
    for _, row in ipairs(rows) do
        options[#options + 1] = {
            title = row.label,
            description = ('$%s • %s available • stored at %s'):format(money(row.price), row.quantity, row.garage),
            icon = 'car-side',
            onSelect = function()
                local confirm = lib.alertDialog({ header = row.label, content = ('Purchase for $%s from your bank?'):format(money(row.price)), cancel = true, centered = true })
                if confirm == 'confirm' then TriggerServerEvent('lotb_autos:buy', row.stock_key) end
            end
        }
    end
    if #options == 0 then options[1] = { title = 'No vehicles in stock', description = 'This dealership is currently empty.' } end
    lib.registerContext({ id = 'lotb_dealer', title = 'LOTB Dealership', options = options })
    lib.showContext('lotb_dealer')
end, false)

RegisterCommand('mycars', function()
    local rows = lib.callback.await('lotb_autos:myVehicles', false) or {}
    local options = {}
    for _, row in ipairs(rows) do
        options[#options + 1] = {
            title = row.modelName or ('Vehicle #' .. tostring(row.id)),
            description = ('ID %s • garage %s • state %s'):format(row.id, row.garage or 'unknown', tostring(row.state)),
            icon = 'warehouse'
        }
    end
    if #options == 0 then options[1] = { title = 'No registered vehicles' } end
    lib.registerContext({ id = 'lotb_mycars', title = 'Registered Vehicles', options = options })
    lib.showContext('lotb_mycars')
end, false)

RegisterCommand('dealerstock', function()
    local input = lib.inputDialog('Dealer stock admin', {
        { type = 'input', label = 'Stock key (optional)' },
        { type = 'input', label = 'Dealership key', default = 'city_motors', required = true },
        { type = 'input', label = 'Vehicle model', required = true },
        { type = 'input', label = 'Display label', required = true },
        { type = 'number', label = 'Price', min = 1, required = true },
        { type = 'number', label = 'Quantity', min = 0, required = true },
        { type = 'input', label = 'Garage', default = 'pillboxgarage', required = true }
    })
    if input then
        TriggerServerEvent('lotb_autos:adminStock', {
            stockKey = input[1], dealershipKey = input[2], model = input[3], label = input[4], price = input[5], quantity = input[6], garage = input[7]
        })
    end
end, false)
