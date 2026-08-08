local config = require 'config.shared'

local function key(prefix) return ('%s-%d-%05d'):format(prefix,os.time(),math.random(0,99999)) end
local function cid(source) return exports.lotb_core:GetCitizenId(source) end

local function siteByKey(siteKey)
    for _,site in ipairs(config.sites) do if site.key==siteKey then return site end end
end

local function distanceFrom(source,coords)
    local ped=GetPlayerPed(source); if not ped or ped<=0 then return 99999 end
    local p=GetEntityCoords(ped); local dx,dy,dz=p.x-coords.x,p.y-coords.y,p.z-coords.z
    return math.sqrt(dx*dx+dy*dy+dz*dz)
end

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS lotb_civic_jobs (
          job_key VARCHAR(96) NOT NULL,
          citizenid VARCHAR(64) NOT NULL,
          site_key VARCHAR(96) NOT NULL,
          district VARCHAR(64) NOT NULL,
          kind VARCHAR(64) NOT NULL,
          status VARCHAR(32) NOT NULL DEFAULT 'active',
          payout INT NOT NULL DEFAULT 0,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          completed_at DATETIME NULL,
          PRIMARY KEY(job_key),
          KEY idx_lotb_civic_citizen(citizenid),
          KEY idx_lotb_civic_status(status)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
end)

lib.callback.register('lotb_civicwork:active',function(source)
    local citizenid=cid(source); if not citizenid then return nil end
    return MySQL.single.await("SELECT * FROM lotb_civic_jobs WHERE citizenid=? AND status='active' ORDER BY created_at DESC LIMIT 1",{citizenid})
end)

lib.callback.register('lotb_civicwork:request',function(source)
    local citizenid=cid(source); if not citizenid then return nil,'no_character' end
    local active=MySQL.single.await("SELECT * FROM lotb_civic_jobs WHERE citizenid=? AND status='active' ORDER BY created_at DESC LIMIT 1",{citizenid})
    if active then return active end
    local cooling=MySQL.scalar.await([[
      SELECT 1 FROM lotb_civic_jobs WHERE citizenid=? AND created_at>DATE_SUB(NOW(),INTERVAL ? MINUTE) LIMIT 1
    ]],{citizenid,config.cooldownMinutes})
    if cooling then return nil,'cooldown' end

    local weighted={}
    for _,site in ipairs(config.sites) do
        local state=MySQL.single.await('SELECT trust,pressure,prosperity,instability,community_pride FROM lotb_district_state WHERE district=?',{site.district}) or {}
        local weight=1
        if site.kind=='cleanup' then weight=weight+math.max(0,math.floor((tonumber(state.instability) or 0)/10)) end
        if site.kind=='repair' or site.kind=='logistics' then weight=weight+math.max(0,math.floor(-(tonumber(state.prosperity) or 0)/10)) end
        if site.kind=='inspection' then weight=weight+math.max(0,math.floor(-(tonumber(state.trust) or 0)/10)) end
        for _=1,math.min(8,weight) do weighted[#weighted+1]=site end
    end
    local site=weighted[math.random(1,#weighted)]
    local jobKey=key('CIVIC'); local payout=math.random(site.pay.min,site.pay.max)
    MySQL.insert.await('INSERT INTO lotb_civic_jobs(job_key,citizenid,site_key,district,kind,payout) VALUES(?,?,?,?,?,?)',{jobKey,citizenid,site.key,site.district,site.kind,payout})
    exports.lotb_core:Audit('civic',source,'assign',jobKey,{site=site.key,district=site.district})
    return {job_key=jobKey,citizenid=citizenid,site_key=site.key,district=site.district,kind=site.kind,status='active',payout=payout,label=site.label,coords={x=site.coords.x,y=site.coords.y,z=site.coords.z}}
end)

lib.callback.register('lotb_civicwork:details',function(source,jobKey)
    local citizenid=cid(source); if not citizenid then return nil end
    local job=MySQL.single.await("SELECT * FROM lotb_civic_jobs WHERE job_key=? AND citizenid=? AND status='active' LIMIT 1",{jobKey,citizenid})
    if not job then return nil end
    local site=siteByKey(job.site_key); if not site then return nil end
    job.label=site.label; job.coords={x=site.coords.x,y=site.coords.y,z=site.coords.z}; return job
end)

lib.callback.register('lotb_civicwork:complete',function(source,jobKey)
    local citizenid=cid(source); if not citizenid then return false end
    local job=MySQL.single.await("SELECT * FROM lotb_civic_jobs WHERE job_key=? AND citizenid=? AND status='active' LIMIT 1",{jobKey,citizenid})
    if not job then return false end
    local site=siteByKey(job.site_key); if not site or distanceFrom(source,site.coords)>config.completionDistance then return false end
    local changed=MySQL.update.await("UPDATE lotb_civic_jobs SET status='completed',completed_at=NOW() WHERE job_key=? AND status='active'",{jobKey})
    if not changed or changed<1 then return false end
    exports.qbx_core:AddMoney(source,'bank',job.payout,'lotb-civic-work')
    exports.lotb_citymemory:AddMemory(citizenid,'community_trust',2,{kind=site.kind,district=site.district})
    exports.lotb_citymemory:ChangeDistrict(site.district,site.effect)
    exports.lotb_core:Audit('civic',source,'complete',jobKey,{site=site.key,payout=job.payout,effect=site.effect})
    return true,job.payout
end)
