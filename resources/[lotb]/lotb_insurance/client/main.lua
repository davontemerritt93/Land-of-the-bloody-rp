local config = require 'config.shared'

local function money(n)
    local s=tostring(math.floor(tonumber(n) or 0)); while true do local k; s,k=s:gsub('^(-?%d+)(%d%d%d)','%1,%2'); if k==0 then break end end; return s
end

local function buyPolicy()
    local planOptions={}
    for key,plan in pairs(config.plans) do
        planOptions[#planOptions+1]={ value=key,label=('%s — $%s / %s days'):format(plan.label,money(plan.premium),config.termDays) }
    end
    local input=lib.inputDialog('Buy insurance policy',{
        {type='select',label='Asset type',required=true,options={{value='vehicle',label='Registered vehicle'},{value='property',label='Property'},{value='business',label='Business'}}},
        {type='input',label='Asset reference',description='Vehicle ID, property key, or business key',required=true},
        {type='select',label='Coverage plan',required=true,options=planOptions}
    })
    if input then TriggerServerEvent('lotb_insurance:buyPolicy',input[1],input[2],input[3]) end
end

local function submitClaim(policy)
    local input=lib.inputDialog('Insurance claim',{
        {type='select',label='Incident type',required=true,options={{value='collision',label='Collision'},{value='theft',label='Theft'},{value='fire',label='Fire'},{value='vandalism',label='Vandalism'},{value='property_damage',label='Property damage'},{value='business_loss',label='Business loss'},{value='other',label='Other'}}},
        {type='textarea',label='What happened?',min=20,max=1000,required=true},
        {type='number',label='Requested amount',min=1,max=policy.coverage_limit,required=true},
        {type='input',label='Evidence keys (optional)',description='Comma-separated LOTB evidence IDs. Invalid IDs are ignored.'}
    })
    if input then TriggerServerEvent('lotb_insurance:submitClaim',{policyKey=policy.policy_key,incidentType=input[1],description=input[2],requestedAmount=input[3],evidence=input[4] or ''}) end
end

local function policyMenu(policy)
    local options={
        {title=('%s: %s'):format(policy.asset_type,policy.asset_ref),description=('Coverage $%s • deductible $%s • status %s'):format(money(policy.coverage_limit),money(policy.deductible),policy.status),icon='shield-halved'}
    }
    if policy.status=='active' then
        options[#options+1]={title='File a claim',icon='file-circle-exclamation',onSelect=function() submitClaim(policy) end}
    elseif policy.status=='payment_due' then
        options[#options+1]={title=('Renew for $%s'):format(money(policy.premium)),icon='rotate',onSelect=function() TriggerServerEvent('lotb_insurance:renewPolicy',policy.policy_key) end}
    end
    lib.registerContext({id='lotb_policy',title='Insurance Policy',options=options}); lib.showContext('lotb_policy')
end

local function reviewClaim(claim)
    local evidence=lib.callback.await('lotb_insurance:evidence',false,claim.claim_key) or {}
    local evidenceText='No validated evidence attached.'
    if #evidence>0 then
        local parts={}; for _,ev in ipairs(evidence) do parts[#parts+1]=('%s (%s, integrity %s/100)'):format(ev.evidence_key,ev.evidence_type,ev.integrity) end; evidenceText=table.concat(parts,'\n')
    end
    local max=math.max(0,math.min(claim.requested_amount or 0,claim.coverage_limit or 0)-(claim.deductible or 0))
    local choice=lib.inputDialog(('Review %s'):format(claim.claim_key),{
        {type='textarea',label='Claim summary',default=('%s\n\nEvidence:\n%s'):format(claim.description,evidenceText),disabled=true},
        {type='select',label='Decision',required=true,options={{value='approve',label='Approve'},{value='deny',label='Deny'}}},
        {type='number',label=('Approved payout (maximum $%s)'):format(money(max)),min=0,max=max,default=max},
        {type='textarea',label='Review note',max=800}
    })
    if choice then TriggerServerEvent('lotb_insurance:reviewClaim',claim.claim_key,choice[2],choice[3],choice[4] or '') end
end

RegisterCommand('insurance',function()
    local data=lib.callback.await('lotb_insurance:overview',false); if not data then return end
    local options={{title='Buy a policy',description='Vehicle, property, or business coverage',icon='shield',onSelect=buyPolicy}}
    for _,policy in ipairs(data.policies or {}) do
        options[#options+1]={title=('%s • %s'):format(policy.asset_type,policy.asset_ref),description=('Status %s • coverage $%s'):format(policy.status,money(policy.coverage_limit)),icon='file-shield',onSelect=function() policyMenu(policy) end}
    end
    for _,claim in ipairs(data.claims or {}) do
        options[#options+1]={title=('%s • %s'):format(claim.claim_key,claim.status),description=('%s • requested $%s%s'):format(claim.incident_type,money(claim.requested_amount),claim.review_note and (' — '..claim.review_note) or ''),icon='file-invoice',onSelect=function()
            if claim.status=='approved' then
                local ok=lib.alertDialog({header='Collect approved claim?',content=('Deposit $%s to your bank?'):format(money(claim.approved_amount)),cancel=true,centered=true})
                if ok=='confirm' then TriggerServerEvent('lotb_insurance:collectClaim',claim.claim_key) end
            end
        end}
    end
    if data.adjuster then
        options[#options+1]={title='Adjuster claim queue',icon='clipboard-check',onSelect=function()
            local rows=lib.callback.await('lotb_insurance:reviewQueue',false) or {}; local review={}
            for _,claim in ipairs(rows) do review[#review+1]={title=('%s • %s'):format(claim.claim_key,claim.asset_type),description=('%s • requested $%s'):format(claim.incident_type,money(claim.requested_amount)),icon='magnifying-glass-dollar',onSelect=function() reviewClaim(claim) end} end
            if #review==0 then review[1]={title='No claims awaiting review'} end
            lib.registerContext({id='lotb_claim_queue',title='Adjuster Queue',options=review}); lib.showContext('lotb_claim_queue')
        end}
    end
    lib.registerContext({id='lotb_insurance',title='LOTB Insurance',options=options}); lib.showContext('lotb_insurance')
end,false)
