local function encode(value)
    return json.encode(type(value) == 'table' and value or {})
end

local function createOrUpdate(data)
    if type(data) ~= 'table' then return false, 'invalid_data' end
    if type(data.key) ~= 'string' or data.key == '' then return false, 'missing_key' end
    if type(data.title) ~= 'string' or data.title == '' then return false, 'missing_title' end

    MySQL.insert.await([[
        INSERT INTO lotb_scene_threads
            (thread_key, title, category, status, owner_citizenid, participants_json, state_json, expires_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            title = VALUES(title),
            category = VALUES(category),
            status = VALUES(status),
            owner_citizenid = VALUES(owner_citizenid),
            participants_json = VALUES(participants_json),
            state_json = VALUES(state_json),
            expires_at = VALUES(expires_at),
            updated_at = CURRENT_TIMESTAMP
    ]], {
        exports.lotb_core:CleanText(data.key, 96),
        exports.lotb_core:CleanText(data.title, 160),
        exports.lotb_core:CleanText(data.category or 'general', 64),
        exports.lotb_core:CleanText(data.status or 'open', 32),
        data.ownerCitizenId,
        encode(data.participants),
        encode(data.state),
        data.expiresAt
    })

    return true
end
exports('CreateOrUpdateThread', createOrUpdate)

exports('GetThread', function(key)
    local row = MySQL.single.await('SELECT * FROM lotb_scene_threads WHERE thread_key = ?', { key })
    if not row then return nil end
    row.participants = row.participants_json and json.decode(row.participants_json) or {}
    row.state = row.state_json and json.decode(row.state_json) or {}
    row.participants_json = nil
    row.state_json = nil
    return row
end)

exports('CloseThread', function(key, finalState)
    local affected = MySQL.update.await([[
        UPDATE lotb_scene_threads
        SET status = 'closed', state_json = ?, updated_at = CURRENT_TIMESTAMP
        WHERE thread_key = ?
    ]], { encode(finalState), key })
    return affected and affected > 0
end)

exports('ListCharacterThreads', function(citizenid)
    if type(citizenid) ~= 'string' then return {} end
    local needle = ('%%"%s"%%'):format(citizenid)
    return MySQL.query.await([[
        SELECT thread_key, title, category, status, updated_at
        FROM lotb_scene_threads
        WHERE owner_citizenid = ? OR participants_json LIKE ?
        ORDER BY updated_at DESC LIMIT 25
    ]], { citizenid, needle }) or {}
end)

CreateThread(function()
    while true do
        Wait(15 * 60 * 1000)
        MySQL.update.await([[
            UPDATE lotb_scene_threads
            SET status = 'expired'
            WHERE status = 'open' AND expires_at IS NOT NULL AND expires_at < NOW()
        ]])
    end
end)
