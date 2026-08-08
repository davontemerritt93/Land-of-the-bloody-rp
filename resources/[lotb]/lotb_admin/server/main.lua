local function isAdmin(source)
    return exports.lotb_core:HasAce(source, 'lotb.admin')
end

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS lotb_staff_notes (
          id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
          target_citizenid VARCHAR(64) NOT NULL,
          author_citizenid VARCHAR(64) NULL,
          note_type VARCHAR(32) NOT NULL DEFAULT 'note',
          body VARCHAR(800) NOT NULL,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (id),
          KEY idx_lotb_staff_target (target_citizenid),
          KEY idx_lotb_staff_created (created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
end)

lib.callback.register('lotb_admin:overview', function(source)
    if not isAdmin(source) then return nil end
    return {
        audits = MySQL.query.await([[
            SELECT category,actor_citizenid,actor_source,action,target,created_at
            FROM lotb_audit_log ORDER BY id DESC LIMIT 50
        ]]) or {},
        notes = MySQL.query.await([[
            SELECT id,target_citizenid,author_citizenid,note_type,body,created_at
            FROM lotb_staff_notes ORDER BY id DESC LIMIT 30
        ]]) or {}
    }
end)

lib.callback.register('lotb_admin:playerNotes', function(source, citizenid)
    if not isAdmin(source) then return nil end
    citizenid = exports.lotb_core:CleanText(citizenid or '', 64)
    if citizenid == '' then return {} end
    return MySQL.query.await([[
        SELECT id,author_citizenid,note_type,body,created_at
        FROM lotb_staff_notes WHERE target_citizenid=? ORDER BY id DESC LIMIT 50
    ]], { citizenid }) or {}
end)

RegisterNetEvent('lotb_admin:addNote', function(targetCitizenId, noteType, body)
    local source = source
    if not isAdmin(source) then return end
    local author = exports.lotb_core:GetCitizenId(source)
    targetCitizenId = exports.lotb_core:CleanText(targetCitizenId or '', 64)
    noteType = exports.lotb_core:CleanText(noteType or 'note', 32)
    body = exports.lotb_core:CleanText(body or '', 800)
    if targetCitizenId == '' or body == '' then return end
    MySQL.insert.await([[
        INSERT INTO lotb_staff_notes (target_citizenid,author_citizenid,note_type,body)
        VALUES (?,?,?,?)
    ]], { targetCitizenId, author, noteType, body })
    exports.lotb_core:Audit('staff', source, 'add_note', targetCitizenId, { type = noteType })
    exports.lotb_core:Notify(source, 'Staff note saved.', 'success')
end)

RegisterNetEvent('lotb_admin:warnOnline', function(targetSource, message)
    local source = source
    if not isAdmin(source) then return end
    targetSource = tonumber(targetSource)
    message = exports.lotb_core:CleanText(message or '', 500)
    if not targetSource or targetSource <= 0 or message == '' or not GetPlayerName(targetSource) then return end
    local targetCid = exports.lotb_core:GetCitizenId(targetSource)
    if targetCid then
        MySQL.insert.await([[
            INSERT INTO lotb_staff_notes (target_citizenid,author_citizenid,note_type,body)
            VALUES (?,?, 'warning', ?)
        ]], { targetCid, exports.lotb_core:GetCitizenId(source), message })
    end
    exports.qbx_core:Notify(targetSource, ('Staff warning: %s'):format(message), 'warning', 12000)
    exports.lotb_core:Audit('staff', source, 'warn_player', targetCid or tostring(targetSource), { message = message })
    exports.lotb_core:Notify(source, 'Warning sent and logged.', 'success')
end)

exports('IsAdmin', isAdmin)
