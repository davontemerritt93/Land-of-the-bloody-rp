local function justiceAccess(source)
    if source == 0 then return true end
    if exports.lotb_core:HasAce(source, 'lotb.justice.manage') then return true end
    return exports.qbx_core:HasGroup(source, { police = 0 }) == true
end

local function key(prefix)
    return ('%s-%d-%04d'):format(prefix, os.time(), math.random(0, 9999))
end

exports('CreateCase', function(data)
    if type(data) ~= 'table' or type(data.title) ~= 'string' then return nil end
    local caseKey = data.key or key('CASE')
    MySQL.insert.await([[
        INSERT INTO lotb_justice_cases (case_key, title, status, judge_citizenid, parties_json, summary, precedent_json)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE title = VALUES(title), status = VALUES(status), judge_citizenid = VALUES(judge_citizenid), parties_json = VALUES(parties_json), summary = VALUES(summary), precedent_json = VALUES(precedent_json)
    ]], {
        caseKey,
        exports.lotb_core:CleanText(data.title, 160),
        exports.lotb_core:CleanText(data.status or 'open', 32),
        data.judgeCitizenId,
        json.encode(type(data.parties) == 'table' and data.parties or {}),
        exports.lotb_core:CleanText(data.summary or '', 1000),
        json.encode(type(data.precedent) == 'table' and data.precedent or {})
    })
    return caseKey
end)

exports('IssueWarrant', function(data)
    if type(data) ~= 'table' or type(data.citizenid) ~= 'string' or type(data.reason) ~= 'string' then return nil end
    local warrantKey = data.key or key('WAR')
    MySQL.insert.await([[
        INSERT INTO lotb_warrants (warrant_key, citizenid, case_key, reason, status, issued_by, expires_at)
        VALUES (?, ?, ?, ?, 'active', ?, ?)
    ]], {
        warrantKey,
        data.citizenid,
        data.caseKey,
        exports.lotb_core:CleanText(data.reason, 500),
        data.issuedByCitizenId,
        data.expiresAt
    })
    return warrantKey
end)

lib.callback.register('lotb_justice:getCase', function(source, caseKey)
    if not justiceAccess(source) or type(caseKey) ~= 'string' then return nil end
    local row = MySQL.single.await('SELECT * FROM lotb_justice_cases WHERE case_key = ?', { caseKey })
    if not row then return nil end
    row.parties = row.parties_json and json.decode(row.parties_json) or {}
    row.precedent = row.precedent_json and json.decode(row.precedent_json) or {}
    row.parties_json = nil
    row.precedent_json = nil
    row.evidence = MySQL.query.await('SELECT evidence_key, evidence_type, integrity FROM lotb_evidence WHERE case_ref = ? ORDER BY created_at', { caseKey }) or {}
    return row
end)

lib.callback.register('lotb_justice:getWarrantsBySource', function(source, targetSource)
    if not justiceAccess(source) then return {} end
    targetSource = tonumber(targetSource)
    local target = targetSource and exports.qbx_core:GetPlayer(targetSource) or nil
    if not target then return {} end
    return MySQL.query.await([[
        SELECT warrant_key, case_key, reason, status, expires_at, created_at
        FROM lotb_warrants
        WHERE citizenid = ? AND status = 'active' AND (expires_at IS NULL OR expires_at > NOW())
        ORDER BY created_at DESC
    ]], { target.PlayerData.citizenid }) or {}
end)

RegisterCommand('casecreate', function(source, args)
    if not exports.lotb_core:HasAce(source, 'lotb.justice.manage') then return end
    local title = table.concat(args, ' ')
    if #title < 3 then return exports.lotb_core:Notify(source, 'Usage: /casecreate [title]', 'error') end
    local caseKey = exports.lotb_justice:CreateCase({ title = title, judgeCitizenId = exports.lotb_core:GetCitizenId(source) })
    exports.lotb_core:Audit('justice', source, 'create_case', caseKey, { title = title })
    exports.lotb_core:Notify(source, ('Case created: %s'):format(caseKey), 'success')
end, false)

RegisterCommand('warrantissue', function(source, args)
    if not exports.lotb_core:HasAce(source, 'lotb.justice.manage') then return end
    local targetSource = tonumber(args[1])
    local caseKey = args[2]
    local reason = table.concat(args, ' ', 3)
    local target = targetSource and exports.qbx_core:GetPlayer(targetSource) or nil
    if not target or not caseKey or #reason < 5 then
        return exports.lotb_core:Notify(source, 'Usage: /warrantissue [player-id] [case-key] [reason]', 'error')
    end
    local warrantKey = exports.lotb_justice:IssueWarrant({
        citizenid = target.PlayerData.citizenid,
        caseKey = caseKey,
        reason = reason,
        issuedByCitizenId = exports.lotb_core:GetCitizenId(source)
    })
    exports.lotb_core:Audit('justice', source, 'issue_warrant', warrantKey, { target = target.PlayerData.citizenid, case = caseKey })
    exports.lotb_core:Notify(source, ('Warrant issued: %s'):format(warrantKey), 'success')
end, false)
