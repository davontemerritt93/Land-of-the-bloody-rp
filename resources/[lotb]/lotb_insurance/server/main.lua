local config = require 'config.shared'

local function makeKey(prefix)
    return ('%s-%d-%05d'):format(prefix, os.time(), math.random(0, 99999))
end

local function cid(source)
    return exports.lotb_core:GetCitizenId(source)
end

local function groups(source)
    return exports.qbx_core:GetGroups(source) or {}
end

local function isAdjuster(source)
    if exports.lotb_core:HasAce(source, 'lotb.admin') or exports.lotb_core:HasAce(source, 'lotb.business.manage') then return true end
    local g = groups(source)
    return g.insurance ~= nil or g.adjuster ~= nil
end

local function ownsAsset(source, citizenid, assetType, assetRef)
    if assetType == 'vehicle' then
        local vehicleId = math.floor(tonumber(assetRef) or 0)
        if vehicleId <= 0 then return false end
        return exports.qbx_vehicles:GetPlayerVehicle(vehicleId, { citizenid = citizenid }) ~= nil
    elseif assetType == 'property' then
        return MySQL.scalar.await('SELECT 1 FROM lotb_properties WHERE property_key=? AND owner_citizenid=? LIMIT 1', { assetRef, citizenid }) == 1
    elseif assetType == 'business' then
        return MySQL.scalar.await('SELECT 1 FROM lotb_businesses WHERE business_key=? AND owner_citizenid=? LIMIT 1', { assetRef, citizenid }) == 1
    end
    return false
end

local function validEvidence(csv)
    if type(csv) ~= 'string' or csv == '' then return {} end
    local out, seen = {}, {}
    for token in csv:gmatch('[^,%s]+') do
        token = exports.lotb_core:CleanText(token, 96)
        if token ~= '' and not seen[token] and #out < config.maxEvidenceRefs then
            local exists = MySQL.scalar.await('SELECT 1 FROM lotb_evidence WHERE evidence_key=? LIMIT 1', { token })
            if exists then
                seen[token] = true
                out[#out + 1] = token
            end
        end
    end
    return out
end

lib.callback.register('lotb_insurance:overview', function(source)
    local citizenid = cid(source)
    if not citizenid then return nil end
    local policies = MySQL.query.await([[
        SELECT policy_key,asset_type,asset_ref,coverage_limit,deductible,premium,status,next_due_at,created_at
        FROM lotb_insurance_policies WHERE holder_citizenid=? ORDER BY created_at DESC
    ]], { citizenid }) or {}
    local claims = MySQL.query.await([[
        SELECT c.claim_key,c.policy_key,c.incident_type,c.description,c.requested_amount,c.approved_amount,c.status,c.review_note,c.created_at,c.reviewed_at,
               p.asset_type,p.asset_ref,p.coverage_limit,p.deductible
        FROM lotb_insurance_claims c
        JOIN lotb_insurance_policies p ON p.policy_key=c.policy_key
        WHERE c.claimant_citizenid=? ORDER BY c.created_at DESC LIMIT 30
    ]], { citizenid }) or {}
    return { policies = policies, claims = claims, adjuster = isAdjuster(source) }
end)

lib.callback.register('lotb_insurance:reviewQueue', function(source)
    if not isAdjuster(source) then return nil end
    local rows = MySQL.query.await([[
        SELECT c.claim_key,c.policy_key,c.claimant_citizenid,c.incident_type,c.description,c.requested_amount,c.evidence_json,c.created_at,
               p.asset_type,p.asset_ref,p.coverage_limit,p.deductible
        FROM lotb_insurance_claims c
        JOIN lotb_insurance_policies p ON p.policy_key=c.policy_key
        WHERE c.status='submitted' ORDER BY c.created_at ASC LIMIT 50
    ]]) or {}
    for _, row in ipairs(rows) do row.evidence = row.evidence_json and json.decode(row.evidence_json) or {} end
    return rows
end)

lib.callback.register('lotb_insurance:evidence', function(source, claimKey)
    if not isAdjuster(source) then return {} end
    local claim = MySQL.single.await('SELECT evidence_json FROM lotb_insurance_claims WHERE claim_key=?', { claimKey })
    if not claim then return {} end
    local keys = claim.evidence_json and json.decode(claim.evidence_json) or {}
    local out = {}
    for _, evidenceKey in ipairs(keys) do
        local ev = MySQL.single.await([[
            SELECT evidence_key,evidence_type,case_ref,integrity,created_at FROM lotb_evidence WHERE evidence_key=?
        ]], { evidenceKey })
        if ev then out[#out + 1] = ev end
    end
    return out
end)

RegisterNetEvent('lotb_insurance:buyPolicy', function(assetType, assetRef, planKey)
    local source = source
    local citizenid = cid(source)
    assetType = exports.lotb_core:CleanText(assetType or '', 32)
    assetRef = exports.lotb_core:CleanText(tostring(assetRef or ''), 128)
    planKey = exports.lotb_core:CleanText(planKey or '', 32)
    local plan = config.plans[planKey]
    if not citizenid or not plan or not ownsAsset(source, citizenid, assetType, assetRef) then
        return exports.lotb_core:Notify(source, 'That asset cannot be insured by you.', 'error')
    end

    local active = MySQL.scalar.await([[
        SELECT 1 FROM lotb_insurance_policies
        WHERE holder_citizenid=? AND asset_type=? AND asset_ref=? AND status IN ('active','payment_due') LIMIT 1
    ]], { citizenid, assetType, assetRef })
    if active then return exports.lotb_core:Notify(source, 'That asset already has a current policy.', 'error') end

    if not exports.qbx_core:RemoveMoney(source, 'bank', plan.premium, 'lotb-insurance-premium') then
        return exports.lotb_core:Notify(source, 'You cannot afford the premium.', 'error')
    end

    local key = makeKey('POL')
    local inserted = MySQL.insert.await([[
        INSERT INTO lotb_insurance_policies
          (policy_key,holder_citizenid,asset_type,asset_ref,coverage_limit,deductible,premium,status,next_due_at)
        VALUES (?,?,?,?,?,?,?,'active',DATE_ADD(NOW(),INTERVAL ? DAY))
    ]], { key, citizenid, assetType, assetRef, plan.coverage, plan.deductible, plan.premium, config.termDays })
    if not inserted then
        exports.qbx_core:AddMoney(source, 'bank', plan.premium, 'lotb-insurance-refund')
        return exports.lotb_core:Notify(source, 'Policy creation failed; premium refunded.', 'error')
    end

    MySQL.insert.await([[
        INSERT INTO lotb_bank_ledger(account_type,account_ref,direction,amount,reason,actor_citizenid)
        VALUES('player',?,'out',?,'insurance premium',?)
    ]], { citizenid, plan.premium, citizenid })
    exports.lotb_core:Audit('insurance', source, 'buy_policy', key, { assetType = assetType, assetRef = assetRef, plan = planKey })
    exports.lotb_core:Notify(source, ('Policy active. Coverage $%s, deductible $%s.'):format(plan.coverage, plan.deductible), 'success')
end)

RegisterNetEvent('lotb_insurance:renewPolicy', function(policyKey)
    local source = source
    local citizenid = cid(source)
    local policy = MySQL.single.await([[
        SELECT * FROM lotb_insurance_policies WHERE policy_key=? AND holder_citizenid=? LIMIT 1
    ]], { policyKey, citizenid })
    if not policy or policy.status == 'cancelled' then return end
    local premium = math.max(0, tonumber(policy.premium) or 0)
    if not exports.qbx_core:RemoveMoney(source, 'bank', premium, 'lotb-insurance-renewal') then
        return exports.lotb_core:Notify(source, 'You cannot afford the renewal premium.', 'error')
    end
    MySQL.update.await([[
        UPDATE lotb_insurance_policies SET status='active',next_due_at=DATE_ADD(NOW(),INTERVAL ? DAY) WHERE policy_key=? AND holder_citizenid=?
    ]], { config.termDays, policyKey, citizenid })
    MySQL.insert.await("INSERT INTO lotb_bank_ledger(account_type,account_ref,direction,amount,reason,actor_citizenid) VALUES('player',?,'out',?,'insurance renewal',?)", { citizenid, premium, citizenid })
    exports.lotb_core:Audit('insurance', source, 'renew_policy', policyKey, { premium = premium })
    exports.lotb_core:Notify(source, 'Policy renewed.', 'success')
end)

RegisterNetEvent('lotb_insurance:submitClaim', function(data)
    local source = source
    local citizenid = cid(source)
    if not citizenid or type(data) ~= 'table' then return end
    local policyKey = exports.lotb_core:CleanText(data.policyKey or '', 96)
    local incidentType = exports.lotb_core:CleanText(data.incidentType or '', 64)
    local description = exports.lotb_core:CleanText(data.description or '', 1000)
    local requested = math.max(1, math.floor(tonumber(data.requestedAmount) or 0))
    if incidentType == '' or #description < 20 then return end

    local policy = MySQL.single.await([[
        SELECT * FROM lotb_insurance_policies
        WHERE policy_key=? AND holder_citizenid=? AND status='active' AND next_due_at>NOW() LIMIT 1
    ]], { policyKey, citizenid })
    if not policy then return exports.lotb_core:Notify(source, 'That policy is not currently active.', 'error') end
    requested = math.min(requested, math.max(0, tonumber(policy.coverage_limit) or 0))
    local open = MySQL.scalar.await("SELECT 1 FROM lotb_insurance_claims WHERE policy_key=? AND status IN ('submitted','approved') LIMIT 1", { policyKey })
    if open then return exports.lotb_core:Notify(source, 'That policy already has an unresolved claim.', 'error') end

    local evidence = validEvidence(data.evidence or '')
    local key = makeKey('CLM')
    MySQL.insert.await([[
        INSERT INTO lotb_insurance_claims
          (claim_key,policy_key,claimant_citizenid,incident_type,description,requested_amount,evidence_json)
        VALUES (?,?,?,?,?,?,?)
    ]], { key, policyKey, citizenid, incidentType, description, requested, json.encode(evidence) })
    exports.lotb_core:Audit('insurance', source, 'submit_claim', key, { policy = policyKey, requested = requested, evidence = evidence })
    exports.lotb_core:Notify(source, ('Claim submitted: %s'):format(key), 'success')
end)

RegisterNetEvent('lotb_insurance:reviewClaim', function(claimKey, decision, approvedAmount, note)
    local source = source
    if not isAdjuster(source) then return end
    local reviewer = cid(source)
    decision = decision == 'approve' and 'approved' or 'denied'
    note = exports.lotb_core:CleanText(note or '', 800)
    local claim = MySQL.single.await([[
        SELECT c.*,p.coverage_limit,p.deductible FROM lotb_insurance_claims c
        JOIN lotb_insurance_policies p ON p.policy_key=c.policy_key
        WHERE c.claim_key=? AND c.status='submitted' LIMIT 1
    ]], { claimKey })
    if not claim then return end

    local amount = 0
    if decision == 'approved' then
        local maximum = math.max(0, math.min(tonumber(claim.requested_amount) or 0, tonumber(claim.coverage_limit) or 0) - (tonumber(claim.deductible) or 0))
        amount = math.max(0, math.min(maximum, math.floor(tonumber(approvedAmount) or maximum)))
        if amount <= 0 then decision = 'denied' end
    end

    local affected = MySQL.update.await([[
        UPDATE lotb_insurance_claims
        SET status=?,approved_amount=?,reviewer_citizenid=?,review_note=?,reviewed_at=NOW()
        WHERE claim_key=? AND status='submitted'
    ]], { decision, amount, reviewer, note, claimKey })
    if not affected or affected < 1 then return end
    exports.lotb_core:Audit('insurance', source, 'review_claim', claimKey, { decision = decision, amount = amount })
    exports.lotb_core:Notify(source, ('Claim %s.'):format(decision), 'success')
end)

RegisterNetEvent('lotb_insurance:collectClaim', function(claimKey)
    local source = source
    local citizenid = cid(source)
    if not citizenid then return end
    local claim = MySQL.single.await([[
        SELECT claim_key,approved_amount FROM lotb_insurance_claims
        WHERE claim_key=? AND claimant_citizenid=? AND status='approved' LIMIT 1
    ]], { claimKey, citizenid })
    if not claim then return end
    local locked = MySQL.update.await("UPDATE lotb_insurance_claims SET status='paying' WHERE claim_key=? AND claimant_citizenid=? AND status='approved'", { claimKey, citizenid })
    if not locked or locked < 1 then return end
    local amount = math.max(0, tonumber(claim.approved_amount) or 0)
    if amount > 0 and exports.qbx_core:AddMoney(source, 'bank', amount, 'lotb-insurance-claim') then
        MySQL.update.await("UPDATE lotb_insurance_claims SET status='paid' WHERE claim_key=? AND status='paying'", { claimKey })
        MySQL.insert.await("INSERT INTO lotb_bank_ledger(account_type,account_ref,direction,amount,reason,actor_citizenid) VALUES('player',?,'in',?,'insurance claim',?)", { citizenid, amount, citizenid })
        exports.lotb_core:Audit('insurance', source, 'collect_claim', claimKey, { amount = amount })
        exports.lotb_core:Notify(source, ('Insurance paid $%s to your bank.'):format(amount), 'success')
    else
        MySQL.update.await("UPDATE lotb_insurance_claims SET status='approved' WHERE claim_key=? AND status='paying'", { claimKey })
        exports.lotb_core:Notify(source, 'Payout could not be completed; the claim remains approved.', 'error')
    end
end)

CreateThread(function()
    while true do
        Wait(60 * 60 * 1000)
        MySQL.update.await("UPDATE lotb_insurance_policies SET status='payment_due' WHERE status='active' AND next_due_at<=NOW()")
    end
end)

exports('IsAdjuster', isAdjuster)
