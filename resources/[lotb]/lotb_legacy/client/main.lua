RegisterCommand('will', function()
    local current = lib.callback.await('lotb_legacy:getMine', false)
    local options = {
        {
            title = 'Write / edit will',
            description = current and ('Current status: %s'):format(current.status) or 'Create your first will',
            icon = 'file-signature',
            onSelect = function()
                local input = lib.inputDialog('Last Will & Testament', {
                    { type = 'input', label = 'Executor citizen ID', default = current and current.executor_citizenid or '' },
                    { type = 'textarea', label = 'Instructions', default = current and current.instructions or '', required = true, min = 1, max = 1500 }
                })
                if input then TriggerServerEvent('lotb_legacy:saveWill', { executor = input[1], instructions = input[2] }) end
            end
        },
        {
            title = 'Add asset',
            description = 'List a property, business, vehicle, heirloom or other RP asset',
            icon = 'box-archive',
            onSelect = function()
                local input = lib.inputDialog('Add will asset', {
                    { type = 'select', label = 'Asset type', required = true, options = {
                        { value = 'property', label = 'Property' },
                        { value = 'business', label = 'Business' },
                        { value = 'vehicle', label = 'Vehicle' },
                        { value = 'legacy_object', label = 'Legacy object' },
                        { value = 'other', label = 'Other RP asset' }
                    }},
                    { type = 'input', label = 'Asset reference', required = true },
                    { type = 'input', label = 'Beneficiary citizen ID', required = true },
                    { type = 'textarea', label = 'Note', max = 500 }
                })
                if input then TriggerServerEvent('lotb_legacy:addAsset', { assetType = input[1], assetRef = input[2], beneficiary = input[3], note = input[4] }) end
            end
        },
        {
            title = 'Finalize will',
            description = 'Make the current draft active',
            icon = 'stamp',
            onSelect = function()
                local ok = lib.alertDialog({ header = 'Finalize will?', content = 'This marks your current will active. You can still replace it later.', centered = true, cancel = true })
                if ok == 'confirm' then TriggerServerEvent('lotb_legacy:finalize') end
            end
        }
    }

    if current and current.assets then
        for _, asset in ipairs(current.assets) do
            options[#options + 1] = {
                title = ('%s: %s'):format(asset.asset_type, asset.asset_ref),
                description = ('Beneficiary: %s%s'):format(asset.beneficiary_citizenid, asset.note and (' — ' .. asset.note) or ''),
                icon = 'scroll'
            }
        end
    end

    lib.registerContext({ id = 'lotb_will', title = 'Character Legacy', options = options })
    lib.showContext('lotb_will')
end, false)
