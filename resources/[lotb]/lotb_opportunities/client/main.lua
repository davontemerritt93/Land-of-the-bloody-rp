RegisterCommand('leads', function()
    local data = lib.callback.await('lotb_opportunities:getLocal', false) or { district = 'unknown', rows = {} }
    if #data.rows == 0 then
        return lib.notify({ title = 'Local Leads', description = 'Nothing is moving in this area right now.', type = 'inform' })
    end

    local options = {}
    for _, row in ipairs(data.rows) do
        options[#options + 1] = {
            title = row.title,
            description = row.body,
            icon = row.kind == 'underworld' and 'user-secret' or (row.kind == 'business' and 'briefcase' or 'people-group')
        }
    end
    lib.registerContext({ id = 'lotb_leads_ctx', title = ('Local Leads — %s'):format(data.district), options = options })
    lib.showContext('lotb_leads_ctx')
end, false)
