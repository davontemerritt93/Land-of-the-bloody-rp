local function band(value)
    value=tonumber(value) or 0
    if value>=60 then return 'excellent' end
    if value>=20 then return 'positive' end
    if value<=-60 then return 'severe concerns' end
    if value<=-20 then return 'concerning' end
    return 'neutral'
end

RegisterCommand('corrections',function()
    local data=lib.callback.await('lotb_corrections:mine',false); if not data then return end
    local options={}
    if data.sentence then
        local s=data.sentence
        options[#options+1]={title=('Active sentence • %s'):format(s.sentence_key),description=('Served %s / %s minutes%s'):format(s.served_minutes or 0,s.total_minutes or 0,s.parole_after_minutes and (' • parole eligible after '..s.parole_after_minutes) or ''),icon='building-shield'}
    else
        options[#options+1]={title='No active sentence',description='You have no active LOTB corrections sentence.',icon='door-open'}
    end
    options[#options+1]={title='Institutional record',description=('Conduct: %s • program progress: %s'):format(band(data.profile and data.profile.conduct),band(data.profile and data.profile.program_credit)),icon='clipboard'}
    options[#options+1]={title='Request visitation',description='Request to visit a character with an active sentence.',icon='people-arrows-left-right',onSelect=function()
        local input=lib.inputDialog('Visitation request',{{type='input',label='Inmate citizen ID',required=true},{type='textarea',label='Note',max=500}})
        if input then TriggerServerEvent('lotb_corrections:requestVisit',input[1],input[2] or '') end
    end}
    for _,visit in ipairs(data.visits or {}) do
        options[#options+1]={title=('Visit %s • %s'):format(visit.visit_key,visit.status),description=('Inmate %s • visitor %s%s'):format(visit.inmate_citizenid,visit.visitor_citizenid,visit.note and (' • '..visit.note) or ''),icon='id-card'}
    end
    lib.registerContext({id='lotb_corrections',title='Corrections',options=options}); lib.showContext('lotb_corrections')
end,false)

RegisterCommand('sentence',function()
    local input=lib.inputDialog('Impose Sentence',{
        {type='input',label='Citizen ID',required=true},
        {type='input',label='Case key (optional)'},
        {type='number',label='Sentence minutes',min=1,max=10080,required=true},
        {type='number',label='Parole eligible after minutes (0 = none)',min=0,max=10080,default=0,required=true},
        {type='textarea',label='Sentencing notes',max=1200}
    })
    if input then TriggerServerEvent('lotb_corrections:imposeSentence',{citizenid=input[1],caseKey=input[2] or '',minutes=input[3],paroleAfter=input[4],notes=input[5] or ''}) end
end,false)

local function lookupStaff(citizenid)
    local data=lib.callback.await('lotb_corrections:staffLookup',false,citizenid)
    if not data then return lib.notify({title='Corrections',description='Corrections access required.',type='error'}) end
    local options={}
    if data.sentence then
        local s=data.sentence
        options[#options+1]={title=s.sentence_key,description=('Served %s/%s • case %s'):format(s.served_minutes or 0,s.total_minutes or 0,s.case_key or 'none'),icon='gavel'}
        options[#options+1]={title='Parole decision',description=s.parole_after_minutes and ('Eligible after '..s.parole_after_minutes..' served minutes') or 'No parole threshold set',icon='scale-balanced',onSelect=function()
            local input=lib.inputDialog('Parole decision',{{type='select',label='Decision',required=true,options={{value='approve',label='Approve'},{value='deny',label='Deny / record denial'}}},{type='textarea',label='Decision note',max=800}})
            if input then TriggerServerEvent('lotb_corrections:parole',citizenid,input[1],input[2] or '') end
        end}
    end
    local p=data.profile or {}
    options[#options+1]={title='Institutional profile',description=('Conduct %s • program credit %s • commissary $%s'):format(p.conduct or 0,p.program_credit or 0,p.commissary_balance or 0),icon='clipboard-user'}
    options[#options+1]={title='Record event/program',icon='file-circle-plus',onSelect=function()
        local input=lib.inputDialog('Corrections event',{
            {type='select',label='Type',required=true,options={{value='conduct',label='Conduct note'},{value='program',label='Program completion'},{value='incident',label='Institutional incident'},{value='work',label='Prison work/program'}}},
            {type='textarea',label='Summary',required=true,max=800},
            {type='number',label='Conduct change (-20 to 20)',min=-20,max=20,default=0,required=true},
            {type='number',label='Program credit change (-20 to 20)',min=-20,max=20,default=0,required=true}
        })
        if input then TriggerServerEvent('lotb_corrections:recordEvent',{citizenid=citizenid,eventType=input[1],summary=input[2],conduct=input[3],credit=input[4]}) end
    end}
    for _,event in ipairs(data.events or {}) do
        options[#options+1]={title=event.event_type,description=('%s • conduct %+d • program %+d'):format(event.summary,event.conduct_delta or 0,event.program_credit_delta or 0),icon='clock-rotate-left'}
    end
    lib.registerContext({id='lotb_corrections_lookup',title=('Corrections: %s'):format(citizenid),options=options}); lib.showContext('lotb_corrections_lookup')
end

RegisterCommand('correctionsstaff',function()
    local input=lib.inputDialog('Corrections staff lookup',{{type='input',label='Citizen ID',required=true}})
    if input then lookupStaff(input[1]) end
end,false)

RegisterCommand('visitqueue',function()
    local rows=lib.callback.await('lotb_corrections:visitQueue',false)
    if not rows then return lib.notify({title='Corrections',description='Corrections access required.',type='error'}) end
    local options={}
    for _,visit in ipairs(rows) do
        options[#options+1]={title=visit.visit_key,description=('Inmate %s • visitor %s'):format(visit.inmate_citizenid,visit.visitor_citizenid),icon='users',onSelect=function()
            local input=lib.inputDialog('Review visit',{{type='select',label='Decision',required=true,options={{value='approve',label='Approve'},{value='deny',label='Deny'}}},{type='textarea',label='Note',max=500}})
            if input then TriggerServerEvent('lotb_corrections:reviewVisit',visit.visit_key,input[1],input[2] or '') end
        end}
    end
    if #options==0 then options[1]={title='No pending visit requests'} end
    lib.registerContext({id='lotb_visit_queue',title='Visitation Queue',options=options}); lib.showContext('lotb_visit_queue')
end,false)
