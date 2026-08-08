local function openProperty(row)
    local options = {
        { title = row.label, description = ('%s • %s • maintenance %s/100'):format(row.property_type, row.district, row.maintenance or 0), icon = 'house' }
    }

    if not row.isOwned and (row.purchase_price or 0) > 0 then
        options[#options + 1] = {
            title = ('Buy for $%s'):format(row.purchase_price),
            icon = 'money-check-dollar',
            onSelect = function()
                local confirm = lib.alertDialog({ header = 'Purchase property?', content = ('Buy %s for $%s from your bank?'):format(row.label, row.purchase_price), cancel = true, centered = true })
                if confirm == 'confirm' then TriggerServerEvent('lotb_properties:buy', row.property_key) end
            end
        }
    elseif row.isOwner then
        options[#options + 1] = {
            title = 'Grant access',
            description = 'Add residents, employees or guests',
            icon = 'key',
            onSelect = function()
                local input = lib.inputDialog('Grant property access', {
                    { type = 'input', label = 'Citizen ID', required = true },
                    { type = 'select', label = 'Access level', required = true, options = {
                        { value = 'resident', label = 'Resident' },
                        { value = 'employee', label = 'Employee' },
                        { value = 'guest', label = 'Guest' }
                    }}
                })
                if input then TriggerServerEvent('lotb_properties:grantAccess', row.property_key, input[1], input[2]) end
            end
        }
        options[#options + 1] = {
            title = 'Property maintenance',
            icon = 'screwdriver-wrench',
            onSelect = function()
                local input = lib.inputDialog('Maintenance', {
                    { type = 'number', label = 'Maintenance points (1-25)', min = 1, max = 25, default = 5, required = true }
                })
                if input then TriggerServerEvent('lotb_properties:maintain', row.property_key, input[1]) end
            end
        }
    elseif row.isOwned then
        options[#options + 1] = {
            title = ('Access: %s'):format(row.access_level or 'authorized'),
            description = 'You can access this property, but owner controls are hidden.',
            icon = 'key'
        }
    end

    lib.registerContext({ id = 'lotb_property_detail', title = 'Property', options = options })
    lib.showContext('lotb_property_detail')
end

RegisterCommand('property', function()
    local rows = lib.callback.await('lotb_properties:listMine', false) or {}
    local nearby = lib.callback.await('lotb_properties:nearby', false) or {}
    local options = {}
    local seen = {}

    for _, row in ipairs(nearby) do
        seen[row.property_key] = true
        options[#options + 1] = {
            title = ('Nearby: %s'):format(row.label),
            description = ('%.1fm • %s'):format(row.distance or 0, row.isOwned and (row.isOwner and 'your property' or 'owned') or ('for sale $' .. tostring(row.purchase_price))),
            icon = 'location-dot',
            onSelect = function() openProperty(row) end
        }
    end

    for _, row in ipairs(rows) do
        if not seen[row.property_key] then
            options[#options + 1] = {
                title = row.label,
                description = ('%s • %s%s'):format(row.district, row.property_type, row.isOwner and ' • owner' or (' • ' .. tostring(row.access_level or 'access'))),
                icon = 'house-user',
                onSelect = function() openProperty(row) end
            }
        end
    end

    if #options == 0 then options[1] = { title = 'No properties found', description = 'Walk near a listed property or receive access from an owner.' } end
    lib.registerContext({ id = 'lotb_properties', title = 'Property', options = options })
    lib.showContext('lotb_properties')
end, false)

RegisterCommand('createproperty', function()
    local coords = GetEntityCoords(cache.ped)
    local input = lib.inputDialog('Create LOTB property', {
        { type = 'input', label = 'Label', required = true },
        { type = 'input', label = 'District key', default = 'downtown', required = true },
        { type = 'select', label = 'Type', required = true, options = {
            { value = 'residential', label = 'Residential' },
            { value = 'commercial', label = 'Commercial' },
            { value = 'warehouse', label = 'Warehouse' },
            { value = 'community', label = 'Community' }
        }},
        { type = 'number', label = 'Purchase price', min = 0, default = 100000, required = true }
    })
    if input then
        TriggerServerEvent('lotb_properties:createAdmin', {
            label = input[1], district = input[2], propertyType = input[3], price = input[4],
            coords = { x = coords.x, y = coords.y, z = coords.z }
        })
    end
end, false)
