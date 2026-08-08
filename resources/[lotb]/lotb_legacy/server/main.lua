local function makeKey(prefix)
    return ('%s-%d-%05d'):format(prefix, os.time(), math.random(0, 99999))
end

local function cid(source)
    return exports.lotb_core:GetCitizenId(source)
end

lib.callback.register('lotb_legacy:getMine', function(source)
    local citizenid = cid(source)
    if not citizenid then return nil end

    local will = MySQL.single.await('SELECT * FROM lotb_wills WHERE citizenid = ? ORDER BY updated_at DESC LIMIT 1', { citizenid })
    if not will then return nil end

    will.assets = MySQL.query.await('SELECT id, asset_type, asset_ref, beneficiary_citizenid, note, status FROM lotb_will_assets WHERE will_key = ? ORDER BY id', { will.will_key }) or {}
    return will
end)

RegisterNetEvent('lotb_legacy:saveWill', function(data)
    local source = source
    local citizenid = cid(source)
    if not citizenid or type(data) ~= 'table' then return end

    local executor = exports.lotb_core:CleanText(data.executor or '', 64)
    local instructions = exports.lotb_core:CleanText(data.instructions or '', 1500)
    local existing = MySQL.single.await('SELECT will_key, status FROM lotb_wills WHERE citizenid = ? ORDER BY updated_at DESC LIMIT 1', { citizenid })
    local key = existing and existing.will_key or makeKey('WILL')

    MySQL.query.await([[
        INSERT INTO lotb_wills (will_key, citizenid, executor_citizenid, status, instructions)
        VALUES (?, ?, NULLIF(?, ''), 'draft', ?)
        ON DUPLICATE KEY UPDATE executor_citizenid = VALUES(executor_citizenid), instructions = VALUES(instructions), updated_at = CURRENT_TIMESTAMP
    ]], { key, citizenid, executor, instructions })

    exports.lotb_core:Audit('legacy', source, 'save_will', key, { executor = executor })
    exports.lotb_core:Notify(source, 'Your will has been saved as a draft.', 'success')
end)

RegisterNetEvent('lotb_legacy:addAsset', function(data)
    local source = source
    local citizenid = cid(source)
    if not citizenid or type(data) ~= 'table' then return end

    local will = MySQL.single.await('SELECT will_key, status FROM lotb_wills WHERE citizenid = ? ORDER BY updated_at DESC LIMIT 1', { citizenid })
    if not will or will.status == 'executed' then
        return exports.lotb_core:Notify(source, 'Create an active will first.', 'error')
    end

    local assetType = exports.lotb_core:CleanText(data.assetType or '', 48)
    local assetRef = exports.lotb_core:CleanText(data.assetRef or '', 128)
    local beneficiary = exports.lotb_core:CleanText(data.beneficiary or '', 64)
    local note = exports.lotb_core:CleanText(data.note or '', 500)
    if assetType == '' or assetRef == '' or beneficiary == '' then return end

    MySQL.insert.await([[
        INSERT INTO lotb_will_assets (will_key, asset_type, asset_ref, beneficiary_citizenid, note)
        VALUES (?, ?, ?, ?, ?)
    ]], { will.will_key, assetType, assetRef, beneficiary, note })

    exports.lotb_core:Audit('legacy', source, 'add_will_asset', will.will_key, { type = assetType, ref = assetRef, beneficiary = beneficiary })
    exports.lotb_core:Notify(source, 'Asset added to your will.', 'success')
end)

RegisterNetEvent('lotb_legacy:finalize', function()
    local source = source
    local citizenid = cid(source)
    if not citizenid then return end

    local affected = MySQL.update.await("UPDATE lotb_wills SET status = 'active', updated_at = CURRENT_TIMESTAMP WHERE citizenid = ? AND status != 'executed'", { citizenid })
    if affected and affected > 0 then
        exports.lotb_core:Audit('legacy', source, 'finalize_will', citizenid, {})
        exports.lotb_core:Notify(source, 'Your will is now active.', 'success')
    end
end)

exports('ExecuteWill', function(citizenid, executorCitizenId)
    local will = MySQL.single.await("SELECT * FROM lotb_wills WHERE citizenid = ? AND status = 'active' ORDER BY updated_at DESC LIMIT 1", { citizenid })
    if not will then return false, 'no_active_will' end
    if will.executor_citizenid and executorCitizenId and will.executor_citizenid ~= executorCitizenId then return false, 'wrong_executor' end

    local assets = MySQL.query.await("SELECT * FROM lotb_will_assets WHERE will_key = ? AND status = 'listed'", { will.will_key }) or {}
    MySQL.update.await("UPDATE lotb_wills SET status = 'executed', updated_at = CURRENT_TIMESTAMP WHERE will_key = ?", { will.will_key })

    return true, assets
end)
