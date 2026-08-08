local function makeKey(prefix)
    return ('%s-%d-%05d'):format(prefix, os.time(), math.random(0, 99999))
end

local function cid(source)
    return exports.lotb_core:GetCitizenId(source)
end

local function isReporter(source)
    if exports.lotb_core:HasAce(source, 'lotb.admin') then return true end
    local g = exports.qbx_core:GetGroups(source) or {}
    return g.reporter ~= nil or g.media ~= nil or g.news ~= nil or g.press ~= nil
end

local function parseSources(value)
    if type(value) ~= 'string' then return {} end
    local out, seen = {}, {}
    for part in value:gmatch('[^,]+') do
        local clean = exports.lotb_core:CleanText(part, 120)
        clean = clean:gsub('^%s+', ''):gsub('%s+$', '')
        if clean ~= '' and not seen[clean] and #out < 8 then
            seen[clean] = true
            out[#out + 1] = clean
        end
    end
    return out
end

lib.callback.register('lotb_media:home', function(source)
    local citizenid = cid(source)
    if not citizenid then return nil end
    local published = MySQL.query.await([[
        SELECT article_key,author_citizenid,outlet,headline,body,category,district,sources_json,status,correction_note,published_at
        FROM lotb_media_articles WHERE status='published' ORDER BY published_at DESC LIMIT 30
    ]]) or {}
    local drafts = {}
    if isReporter(source) then
        drafts = MySQL.query.await([[
            SELECT article_key,outlet,headline,body,category,district,sources_json,status,correction_note,created_at,published_at
            FROM lotb_media_articles WHERE author_citizenid=? ORDER BY created_at DESC LIMIT 30
        ]], { citizenid }) or {}
    end
    return { published = published, drafts = drafts, reporter = isReporter(source) }
end)

RegisterNetEvent('lotb_media:saveDraft', function(data)
    local source = source
    if not isReporter(source) or type(data) ~= 'table' then return end
    local author = cid(source)
    if not author then return end

    local articleKey = exports.lotb_core:CleanText(data.articleKey or '', 96)
    local outlet = exports.lotb_core:CleanText(data.outlet or 'LOTB News', 96)
    local headline = exports.lotb_core:CleanText(data.headline or '', 180)
    local body = exports.lotb_core:CleanText(data.body or '', 6000)
    local category = exports.lotb_core:CleanText(data.category or 'local', 48)
    local district = exports.lotb_core:CleanText(data.district or '', 64)
    local sources = parseSources(data.sources or '')
    if #headline < 5 or #body < 40 then return exports.lotb_core:Notify(source, 'The story needs a real headline and article body.', 'error') end

    if articleKey ~= '' then
        local affected = MySQL.update.await([[
            UPDATE lotb_media_articles SET outlet=?,headline=?,body=?,category=?,district=NULLIF(?,''),sources_json=?
            WHERE article_key=? AND author_citizenid=? AND status='draft'
        ]], { outlet, headline, body, category, district, json.encode(sources), articleKey, author })
        if affected and affected > 0 then
            exports.lotb_core:Audit('media', source, 'update_draft', articleKey, { headline = headline })
            return exports.lotb_core:Notify(source, 'Draft updated.', 'success')
        end
    end

    local key = makeKey('NEWS')
    MySQL.insert.await([[
        INSERT INTO lotb_media_articles(article_key,author_citizenid,outlet,headline,body,category,district,sources_json,status)
        VALUES(?,?,?,?,?,?,NULLIF(?,''),?,'draft')
    ]], { key, author, outlet, headline, body, category, district, json.encode(sources) })
    exports.lotb_core:Audit('media', source, 'create_draft', key, { headline = headline })
    exports.lotb_core:Notify(source, ('Draft saved: %s'):format(key), 'success')
end)

RegisterNetEvent('lotb_media:publish', function(articleKey)
    local source = source
    if not isReporter(source) then return end
    local author = cid(source)
    local article = MySQL.single.await([[
        SELECT * FROM lotb_media_articles WHERE article_key=? AND author_citizenid=? AND status='draft' LIMIT 1
    ]], { articleKey, author })
    if not article then return end

    local affected = MySQL.update.await("UPDATE lotb_media_articles SET status='published',published_at=NOW() WHERE article_key=? AND author_citizenid=? AND status='draft'", { articleKey, author })
    if not affected or affected < 1 then return end

    local feedKey = makeKey('FEED')
    MySQL.insert.await([[
        INSERT INTO lotb_city_services_feed(feed_key,category,title,body,district,priority,expires_at)
        VALUES(?, 'news', ?, ?, NULLIF(?,''), 1, DATE_ADD(NOW(),INTERVAL 72 HOUR))
    ]], { feedKey, article.headline, exports.lotb_core:CleanText(article.body, 500), article.district or '' })

    exports.lotb_core:Audit('media', source, 'publish', articleKey, { feed = feedKey, headline = article.headline })
    exports.lotb_core:Notify(source, 'Story published to the city.', 'success')
end)

RegisterNetEvent('lotb_media:correct', function(articleKey, correction)
    local source = source
    if not isReporter(source) then return end
    local author = cid(source)
    correction = exports.lotb_core:CleanText(correction or '', 800)
    if #correction < 5 then return end
    local affected = MySQL.update.await([[
        UPDATE lotb_media_articles SET correction_note=? WHERE article_key=? AND author_citizenid=? AND status='published'
    ]], { correction, articleKey, author })
    if affected and affected > 0 then
        exports.lotb_core:Audit('media', source, 'correction', articleKey, {})
        exports.lotb_core:Notify(source, 'Correction attached to the published article.', 'success')
    end
end)

RegisterNetEvent('lotb_media:archiveArticle', function(articleKey)
    local source = source
    if not exports.lotb_core:HasAce(source, 'lotb.admin') then return end
    local article = MySQL.single.await("SELECT * FROM lotb_media_articles WHERE article_key=? AND status='published'", { articleKey })
    if not article or GetResourceState('lotb_archive') ~= 'started' then return end
    local archiveKey = exports.lotb_archive:AddArchiveEntry({
        category = 'news',
        title = article.headline,
        summary = exports.lotb_core:CleanText(article.body, 1000),
        district = article.district,
        createdByCitizenId = cid(source),
        related = { article = article.article_key, outlet = article.outlet },
        isPublic = true
    })
    exports.lotb_core:Audit('media', source, 'archive_article', articleKey, { archive = archiveKey })
    exports.lotb_core:Notify(source, ('Article entered into city history: %s'):format(archiveKey), 'success')
end)

exports('IsReporter', isReporter)
