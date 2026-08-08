local function orderMenu(order)
    local options = {
        { title = order.order_key, description = ('Vehicle #%s • %s'):format(order.vehicle_id, order.description), icon = 'screwdriver-wrench' }
    }
    if order.status == 'open' then
        options[#options + 1] = { title = 'Claim order', icon = 'hand', onSelect = function() TriggerServerEvent('lotb_mechanic:claim', order.order_key) end }
    elseif order.status == 'claimed' then
        options[#options + 1] = {
            title = 'Set quote', icon = 'file-invoice-dollar', onSelect = function()
                local input = lib.inputDialog('Repair quote', {{ type = 'number', label = 'Amount', min = 0, max = 250000, required = true }})
                if input then TriggerServerEvent('lotb_mechanic:quote', order.order_key, input[1]) end
            end
        }
    elseif order.status == 'awaiting_payment' then
        options[#options + 1] = { title = ('Pay $%s'):format(order.quoted_price or 0), icon = 'credit-card', onSelect = function() TriggerServerEvent('lotb_mechanic:payOrder', order.order_key) end }
    elseif order.status == 'paid' then
        options[#options + 1] = {
            title = 'Complete service', icon = 'circle-check', onSelect = function()
                local input = lib.inputDialog('Complete service', {
                    { type = 'select', label = 'Service type', required = true, options = {
                        { value = 'repair', label = 'Repair' }, { value = 'maintenance', label = 'Maintenance' }, { value = 'inspection', label = 'Inspection' }, { value = 'performance', label = 'Performance work' }
                    }},
                    { type = 'textarea', label = 'Service summary', required = true, max = 500 },
                    { type = 'number', label = 'Mileage (optional)', min = 0 }
                })
                if input then TriggerServerEvent('lotb_mechanic:complete', order.order_key, input[1], input[2], input[3]) end
            end
        }
    end
    lib.registerContext({ id = 'lotb_mech_order', title = 'Work Order', options = options })
    lib.showContext('lotb_mech_order')
end

RegisterCommand('repairorder', function()
    local input = lib.inputDialog('Open mechanic work order', {
        { type = 'number', label = 'Registered vehicle ID', min = 1, required = true },
        { type = 'textarea', label = 'What needs attention?', required = true, max = 800 }
    })
    if input then TriggerServerEvent('lotb_mechanic:createOrder', { vehicleId = input[1], description = input[2] }) end
end, false)

RegisterCommand('workorders', function()
    local rows = lib.callback.await('lotb_mechanic:myOrders', false) or {}
    local options = {}
    for _, row in ipairs(rows) do
        options[#options + 1] = {
            title = ('%s • %s'):format(row.order_key, row.status),
            description = ('Vehicle #%s — %s'):format(row.vehicle_id, row.description),
            icon = 'clipboard-list',
            onSelect = function() orderMenu(row) end
        }
    end
    if #options == 0 then options[1] = { title = 'No work orders' } end
    lib.registerContext({ id = 'lotb_workorders', title = 'Mechanic Work Orders', options = options })
    lib.showContext('lotb_workorders')
end, false)

RegisterCommand('servicehistory', function(_, args)
    local vehicleId = tonumber(args[1])
    if not vehicleId then
        local input = lib.inputDialog('Vehicle service history', {{ type = 'number', label = 'Vehicle ID', min = 1, required = true }})
        vehicleId = input and input[1]
    end
    if not vehicleId then return end
    local rows = lib.callback.await('lotb_mechanic:history', false, vehicleId) or {}
    local options = {}
    for _, row in ipairs(rows) do
        options[#options + 1] = { title = row.service_type, description = row.summary, icon = 'clock-rotate-left' }
    end
    if #options == 0 then options[1] = { title = 'No recorded service history' } end
    lib.registerContext({ id = 'lotb_servicehistory', title = ('Vehicle #%s History'):format(vehicleId), options = options })
    lib.showContext('lotb_servicehistory')
end, false)
