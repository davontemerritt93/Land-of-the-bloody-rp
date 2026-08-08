RegisterCommand('business', function()
    local businesses = lib.callback.await('lotb_businesses:mine', false) or {}
    if #businesses == 0 then
        return lib.notify({ title = 'Business', description = 'You do not own a registered business.', type = 'inform' })
    end

    local options = {}
    for _, business in ipairs(businesses) do
        local stockLines = {}
        for _, item in ipairs(business.stock or {}) do
            stockLines[#stockLines + 1] = ('%s: %s'):format(item.item_name, item.quantity)
        end
        options[#options + 1] = {
            title = business.name,
            description = ('District: %s | Reputation: %s\n%s'):format(business.district, business.reputation or 0, #stockLines > 0 and table.concat(stockLines, ', ') or 'No stock recorded'),
            icon = 'building'
        }
    end

    lib.registerContext({ id = 'lotb_business_ctx', title = 'My Businesses', options = options })
    lib.showContext('lotb_business_ctx')
end, false)
