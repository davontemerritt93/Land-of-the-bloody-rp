local function money(n)
    local s=tostring(math.floor(tonumber(n) or 0)); while true do local k; s,k=s:gsub('^(-?%d+)(%d%d%d)','%1,%2'); if k==0 then break end end; return s
end

local function simple(id,title,rows,builder)
    local options={}; for _,row in ipairs(rows or {}) do options[#options+1]=builder(row) end
    if #options==0 then options[1]={title='Nothing here right now.'} end
    lib.registerContext({id=id,title=title,options=options}); lib.showContext(id)
end

local function openCityApp()
    local data=lib.callback.await('lotb_cityapp:home',false); if not data then return end
    local options={
        {title=('You are in %s'):format(data.district),description=data.districtSummary,icon='location-dot'},
        {title='City notices',description=('%s active notices'):format(#(data.notices or {})),icon='bell',onSelect=function()
            simple('lotb_city_notices','City Notices',data.notices,function(row)
                return {title=row.title,description=('%s%s\n%s'):format(row.category,row.district and (' • '..row.district) or '',row.body),icon=row.priority>=7 and 'triangle-exclamation' or 'bullhorn'}
            end)
        end},
        {title='LOTB News',description='Player-written reporting, investigations and corrections.',icon='newspaper',onSelect=function() ExecuteCommand('news') end},
        {title='City history',description=('%s recent public records'):format(#(data.archive or {})),icon='landmark',onSelect=function()
            simple('lotb_city_history','City History',data.archive,function(row)
                return {title=row.title,description=('%s%s\n%s'):format(row.category,row.district and (' • '..row.district) or '',row.summary),icon='book-open'}
            end)
        end},
        {title='Contracts',description=('%s recent agreements'):format(#(data.contracts or {})),icon='file-contract',onSelect=function()
            simple('lotb_city_contracts','My Contracts',data.contracts,function(row)
                return {title=row.title,description=('%s • $%s • %s'):format(row.status,money(row.amount),row.contract_key),icon='handshake'}
            end)
        end},
        {title='Properties',description=('%s accessible properties'):format(#(data.properties or {})),icon='house',onSelect=function() ExecuteCommand('property') end},
        {title='Businesses',description=('%s owned businesses'):format(#(data.businesses or {})),icon='store',onSelect=function() if #(data.businesses or {})>0 then ExecuteCommand('banking') else ExecuteCommand('business') end end},
        {title='Insurance',description=('%s recent claims'):format(#(data.insurance or {})),icon='shield-halved',onSelect=function() ExecuteCommand('insurance') end},
        {title='Work board',description='Legitimate public work reacts to neighborhood needs.',icon='helmet-safety',onSelect=function() ExecuteCommand('civicwork') end},
        {title='Word on the street',description='Rumors are not guaranteed facts.',icon='comments',onSelect=function() ExecuteCommand('rumors') end},
        {title='Local opportunities',description='See what circumstances are developing nearby.',icon='compass',onSelect=function() ExecuteCommand('leads') end},
        {title='Emergency services',description='911 for emergencies • 311 for non-emergency city services',icon='phone',onSelect=function()
            local input=lib.inputDialog('City Services',{
                {type='select',label='Service',required=true,options={{value='911',label='911 Emergency'},{value='311',label='311 Non-emergency'}}},
                {type='textarea',label='What is happening?',required=true,min=3,max=500}
            })
            if input then TriggerServerEvent('lotb_dispatch:create',input[1],input[2]) end
        end}
    }
    lib.registerContext({id='lotb_cityapp',title='LAND OF THE BLOODY — CITY',options=options}); lib.showContext('lotb_cityapp')
end

RegisterCommand('cityapp',openCityApp,false)
RegisterNetEvent('lotb_cityapp:open',openCityApp)
exports('OpenCityApp',openCityApp)

RegisterCommand('citynotice',function()
    local input=lib.inputDialog('Publish City Notice',{
        {type='select',label='Category',required=true,options={{value='public_safety',label='Public Safety'},{value='medical',label='Medical'},{value='justice',label='Justice'},{value='community',label='Community'},{value='services',label='City Services'}}},
        {type='input',label='Title',required=true,max=140},
        {type='textarea',label='Notice',required=true,max=600},
        {type='input',label='District',default='citywide',required=true},
        {type='number',label='Priority 0-10',min=0,max=10,default=3,required=true},
        {type='number',label='Hours visible',min=1,max=168,default=24,required=true}
    })
    if input then TriggerServerEvent('lotb_cityapp:publishNotice',{category=input[1],title=input[2],body=input[3],district=input[4],priority=input[5],hours=input[6]}) end
end,false)
