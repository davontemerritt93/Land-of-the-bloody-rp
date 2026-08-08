local active

local function loadJob(job)
    if not job then return end
    if not job.coords then job=lib.callback.await('lotb_civicwork:details',false,job.job_key) end
    if not job then return end
    active=job
    SetNewWaypoint(job.coords.x+0.0,job.coords.y+0.0)
    lib.notify({title='Civic Work',description=job.label or job.kind,type='inform'})
end

RegisterCommand('civicwork',function()
    if active then return loadJob(active) end
    local job,err=lib.callback.await('lotb_civicwork:request',false)
    if not job then
        return lib.notify({title='Civic Work',description=err=='cooldown' and 'Check back after the current work board rotates.' or 'No public work is available.',type='inform'})
    end
    loadJob(job)
end,false)

CreateThread(function()
    Wait(3000)
    local job=lib.callback.await('lotb_civicwork:active',false)
    if job then loadJob(job) end
    while true do
        local wait=1200
        if active and active.coords then
            local here=GetEntityCoords(cache.ped); local c=vec3(active.coords.x+0.0,active.coords.y+0.0,active.coords.z+0.0); local dist=#(here-c)
            if dist<25.0 then
                wait=0
                DrawMarker(2,c.x,c.y,c.z+0.2,0,0,0,0,180.0,0,0.22,0.22,0.22,255,255,255,150,false,true,2,false,nil,nil,false)
                if dist<2.2 then
                    lib.showTextUI('[E] Do the work')
                    if IsControlJustReleased(0,38) then
                        lib.hideTextUI()
                        local duration=active.kind=='cleanup' and 9000 or active.kind=='inspection' and 8000 or 11000
                        local ok=lib.progressCircle({duration=duration,label=active.label or 'Working...',position='bottom',canCancel=true,disable={move=true,car=true,combat=true}})
                        if ok then
                            local success,payout=lib.callback.await('lotb_civicwork:complete',false,active.job_key)
                            if success then
                                lib.notify({title='Work completed',description=('$%s deposited. The neighborhood changed a little because you showed up.'):format(payout or 0),type='success'})
                                active=nil
                            end
                        end
                    end
                else lib.hideTextUI() end
            else lib.hideTextUI() end
        else lib.hideTextUI() end
        Wait(wait)
    end
end)
