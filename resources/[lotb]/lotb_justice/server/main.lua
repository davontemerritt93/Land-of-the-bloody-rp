local function groups(source)
    return exports.qbx_core:GetGroups(source) or {}
end

local function hasAnyGroup(groupTable, names)
    for _, name in ipairs(names) do if groupTable[name] ~= nil then return true end end
    return false
end

local function justiceAccess(source)
    if source == 0 then return true end
    if exports.lotb_core:HasAce(source, 'lotb.justice.manage') or exports.lotb_core:HasAce(source, 'lotb.admin') then return true end
    return hasAnyGroup(groups(source), { 'police','sheriff','state','bcso','sasp','judge','lawyer','doj','prosecutor','publicdefender' })
end

local function judgeAccess(source)
    if source == 0 then return true end
    if exports.lotb_core:HasAce(source, 'lotb.justice.manage') or exports.lotb_core:HasAce(source, 'lotb.admin') then return true end
    return hasAnyGroup(groups(source), { 'judge','doj' })
end

local function key(prefix)
    return ('%s-%d-%04d'):format(prefix, os.time(), math.random(0, 9999))
end

local function parseList(value, maxItems, maxLen)
    if type(value) ~= 'string' then return {} end
    local out, seen = {}, {}
    for part in value:gmatch('[^,]+') do
        local clean = exports.lotb_core:CleanText(part, maxLen or 96):gsub('^%s+',''):gsub('%s+$','')
        if clean ~= '' and not seen[clean] and #out < (maxItems or 10) then seen[clean]=true; out[#out+1]=clean end
    end
    return out
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
    row.rulings = MySQL.query.await([[
        SELECT ruling_key,title,holding,precedential,status,created_at FROM lotb_case_rulings WHERE case_key=? ORDER BY created_at DESC
    ]], { caseKey }) or {}
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

lib.callback.register('lotb_justice:searchPrecedent', function(source, query)
    if not justiceAccess(source) then return nil end
    query = exports.lotb_core:CleanText(query or '', 100)
    if query == '' then
        return MySQL.query.await([[
            SELECT ruling_key,case_key,judge_citizenid,title,holding,rationale,tags_json,citations_json,precedential,status,created_at
            FROM lotb_case_rulings WHERE status='published' ORDER BY created_at DESC LIMIT 30
        ]]) or {}
    end
    local like = '%' .. query .. '%'
    return MySQL.query.await([[
        SELECT ruling_key,case_key,judge_citizenid,title,holding,rationale,tags_json,citations_json,precedential,status,created_at
        FROM lotb_case_rulings
        WHERE status='published' AND (title LIKE ? OR holding LIKE ? OR rationale LIKE ? OR tags_json LIKE ? OR case_key LIKE ?)
        ORDER BY precedential DESC,created_at DESC LIMIT 30
    ]], { like, like, like, like, like }) or {}
end)

RegisterNetEvent('lotb_justice:publishRuling', function(data)
    local source = source
    if not judgeAccess(source) or type(data) ~= 'table' then return end
    local judge = exports.lotb_core:GetCitizenId(source)
    local caseKey = exports.lotb_core:CleanText(data.caseKey or '', 96)
    local title = exports.lotb_core:CleanText(data.title or '', 180)
    local holding = exports.lotb_core:CleanText(data.holding or '', 1200)
    local rationale = exports.lotb_core:CleanText(data.rationale or '', 2000)
    local tags = parseList(data.tags or '', 12, 48)
    local requestedCitations = parseList(data.citations or '', 10, 96)
    local citations = {}
    if caseKey == '' or #title < 5 or #holding < 20 or #rationale < 20 then return end
    local caseExists = MySQL.scalar.await('SELECT 1 FROM lotb_justice_cases WHERE case_key=? LIMIT 1', { caseKey })
    if not caseExists then return exports.lotb_core:Notify(source, 'Case not found.', 'error') end

    for _, citation in ipairs(requestedCitations) do
        if MySQL.scalar.await("SELECT 1 FROM lotb_case_rulings WHERE ruling_key=? AND status='published' LIMIT 1", { citation }) then citations[#citations+1]=citation end
    end

    local rulingKey = key('RULE')
    MySQL.insert.await([[
        INSERT INTO lotb_case_rulings(ruling_key,case_key,judge_citizenid,title,holding,rationale,tags_json,citations_json,precedential,status)
        VALUES(?,?,?,?,?,?,?,?,?,'published')
    ]], { rulingKey, caseKey, judge, title, holding, rationale, json.encode(tags), json.encode(citations), data.precedential == false and 0 or 1 })

    if data.closeCase == true then MySQL.update.await("UPDATE lotb_justice_cases SET status='closed',judge_citizenid=?,updated_at=CURRENT_TIMESTAMP WHERE case_key=?", { judge, caseKey }) end

    if GetResourceState('lotb_archive') == 'started' then
        exports.lotb_archive:AddArchiveEntry({
            category='court ruling', title=title, summary=holding, createdByCitizenId=judge,
            related={case=caseKey,ruling=rulingKey,citations=citations}, isPublic=true
        })
    end
    if GetResourceState('lotb_cityapp') == 'started' then
        MySQL.insert.await([[
            INSERT INTO lotb_city_services_feed(feed_key,category,title,body,district,priority,expires_at)
            VALUES(?, 'justice', ?, ?, 'citywide', 2, DATE_ADD(NOW(),INTERVAL 72 HOUR))
        ]], { key('FEED'), title, exports.lotb_core:CleanText(holding, 500) })
    end
    exports.lotb_core:Audit('justice', source, 'publish_ruling', rulingKey, { case = caseKey, citations = citations, precedential = data.precedential ~= false })
    exports.lotb_core:Notify(source, ('Ruling published: %s'):format(rulingKey), 'success')
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

exports('JusticeAccess', justiceAccess)
exports('JudgeAccess', judgeAccess)
