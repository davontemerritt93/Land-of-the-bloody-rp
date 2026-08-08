local function rumorKey() return ('RUM-%d-%05d'):format(os.time(),math.random(0,99999)) end

exports('SeedRumor', function(data)
    if type(data)~='table' or type(data.subject)~='string' or type(data.body)~='string' then return nil end
    local key=data.key or rumorKey(); local confidence=math.max(1,math.min(100,math.floor(tonumber(data.confidence) or 50)))
    local heat=math.max(0,math.min(100,math.floor(tonumber(data.heat) or 0)))
    MySQL.insert.await([[
        INSERT INTO lotb_rumors (rumor_key,origin_citizenid,district,subject,body,confidence,heat,audience_json,state_json,expires_at)
        VALUES (?,?,?,?,?,?,?,?,?,?)
    ]],{key,data.originCitizenId,data.district,exports.lotb_core:CleanText(data.subject,120),exports.lotb_core:CleanText(data.body,500),confidence,heat,json.encode(data.audience or {}),json.encode(data.state or {}),data.expiresAt})
    return key
end)

lib.callback.register('lotb_rumors:hear',function(source)
    local cid=exports.lotb_core:GetCitizenId(source); if not cid then return {} end
    local rows=MySQL.query.await([[
        SELECT rumor_key,subject,body,confidence,heat,district,created_at
        FROM lotb_rumors
        WHERE (expires_at IS NULL OR expires_at>NOW())
        ORDER BY created_at DESC LIMIT 15
    ]])
    local heard={}
    for _,r in ipairs(rows or {}) do
        local roll=math.random(1,100)
        if roll <= math.max(10,tonumber(r.confidence) or 50) then
            heard[#heard+1]={key=r.rumor_key,subject=r.subject,body=r.body,district=r.district,confidence=r.confidence,heat=r.heat}
        end
        if #heard>=5 then break end
    end
    return heard
end)
