local function makeKey(prefix)
    return ('%s-%d-%05d'):format(prefix, os.time(), math.random(0, 99999))
end

local function clean(value, len)
    return exports.lotb_core:CleanText(value, len)
end

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS lotb_city_archive (
            archive_key VARCHAR(96) NOT NULL,
            category VARCHAR(64) NOT NULL,
            title VARCHAR(160) NOT NULL,
            summary VARCHAR(1000) NOT NULL,
            district VARCHAR(64) NULL,
            related_json LONGTEXT NULL,
            created_by VARCHAR(64) NULL,
            is_public TINYINT(1) NOT NULL DEFAULT 1,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (archive_key),
            KEY idx_lotb_archive_created (created_at),
            KEY idx_lotb_archive_district (district)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS lotb_world_scars (
            scar_key VARCHAR(96) NOT NULL,
            district VARCHAR(64) NULL,
            kind VARCHAR(64) NOT NULL,
            label VARCHAR(220) NOT NULL,
            coords_json LONGTEXT NOT NULL,
            created_by VARCHAR(64) NULL,
            expires_at DATETIME NULL,
            active TINYINT(1) NOT NULL DEFAULT 1,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (scar_key),
            KEY idx_lotb_scar_active (active),
            KEY idx_lotb_scar_district (district)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    lib.print.info('LOTB City Archive / World Scars storage ready')
end)

local function addArchive(data)
    if type(data) ~= 'table' or type(data.title) ~= 'string' or type(data.summary) ~= 'string' then return nil end
    local key = data.key or makeKey('HIST')
    MySQL.insert.await([[
        INSERT INTO lotb_city_archive
            (archive_key, category, title, summary, district, related_json, created_by, is_public)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        key,
        clean(data.category or 'city', 64),
        clean(data.title, 160),
        clean(data.summary, 1000),
        data.district,
        json.encode(type(data.related) == 'table' and data.related or {}),
        data.createdByCitizenId,
        data.isPublic == false and 0 or 1
    })
    return key
end
exports('AddArchiveEntry', addArchive)

local function addScar(data)
    if type(data) ~= 'table' or type(data.kind) ~= 'string' or type(data.label) ~= 'string' or type(data.coords) ~= 'table' then return nil end
    local key = data.key or makeKey('SCAR')
    MySQL.insert.await([[
        INSERT INTO lotb_world_scars
            (scar_key, district, kind, label, coords_json, created_by, expires_at, active)
        VALUES (?, ?, ?, ?, ?, ?, ?, 1)
    ]], {
        key,
        data.district,
        clean(data.kind, 64),
        clean(data.label, 220),
        json.encode(data.coords),
        data.createdByCitizenId,
        data.expiresAt
    })
    return key
end
exports('AddWorldScar', addScar)

lib.callback.register('lotb_archive:list', function()
    return MySQL.query.await([[
        SELECT archive_key, category, title, summary, district, created_at
        FROM lotb_city_archive
        WHERE is_public = 1
        ORDER BY created_at DESC LIMIT 30
    ]]) or {}
end)

lib.callback.register('lotb_archive:scars', function()
    local rows = MySQL.query.await([[
        SELECT scar_key, district, kind, label, coords_json, expires_at
        FROM lotb_world_scars
        WHERE active = 1 AND (expires_at IS NULL OR expires_at > NOW())
        ORDER BY created_at DESC LIMIT 100
    ]]) or {}
    for _, row in ipairs(rows) do
        row.coords = row.coords_json and json.decode(row.coords_json) or nil
        row.coords_json = nil
    end
    return rows
end)

RegisterNetEvent('lotb_archive:addEntry', function(category, title, summary)
    local source = source
    if not exports.lotb_core:HasAce(source, 'lotb.admin') then return end
    if type(title) ~= 'string' or type(summary) ~= 'string' or #title < 3 or #summary < 10 then return end
    local key = addArchive({
        category = category,
        title = title,
        summary = summary,
        district = Player(source).state.lotbDistrict,
        createdByCitizenId = exports.lotb_core:GetCitizenId(source),
        isPublic = true
    })
    exports.lotb_core:Audit('archive', source, 'add_entry', key, { category = category })
    exports.lotb_core:Notify(source, ('City history entry created: %s'):format(key), 'success')
end)

RegisterNetEvent('lotb_archive:addScar', function(kind, label, hours)
    local source = source
    if not exports.lotb_core:HasAce(source, 'lotb.admin') then return end
    if type(kind) ~= 'string' or type(label) ~= 'string' or #label < 3 then return end
    hours = math.max(0, math.min(720, math.floor(tonumber(hours) or 0)))
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return end
    local coords = GetEntityCoords(ped)
    local expiresAt = nil
    if hours > 0 then expiresAt = os.date('%Y-%m-%d %H:%M:%S', os.time() + hours * 3600) end

    local key = addScar({
        kind = kind,
        label = label,
        district = Player(source).state.lotbDistrict,
        coords = { x = coords.x, y = coords.y, z = coords.z },
        createdByCitizenId = exports.lotb_core:GetCitizenId(source),
        expiresAt = expiresAt
    })
    exports.lotb_core:Audit('world_scar', source, 'add', key, { kind = kind, hours = hours })
    exports.lotb_core:Notify(source, ('World scar created: %s'):format(key), 'success')
    TriggerClientEvent('lotb_archive:refreshScars', -1)
end)

CreateThread(function()
    while true do
        Wait(10 * 60 * 1000)
        MySQL.update.await("UPDATE lotb_world_scars SET active = 0 WHERE active = 1 AND expires_at IS NOT NULL AND expires_at <= NOW()")
    end
end)
