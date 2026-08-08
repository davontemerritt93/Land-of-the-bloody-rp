local enabled = true

RegisterCommand('hud', function()
    enabled = not enabled
    SendNUIMessage({ action = 'visible', visible = enabled })
end, false)

CreateThread(function()
    while true do
        Wait(500)
        if enabled and QBX and QBX.PlayerData and QBX.PlayerData.citizenid then
            local ped = cache and cache.ped or PlayerPedId()
            local health = math.max(0, GetEntityHealth(ped) - 100)
            local armor = GetPedArmour(ped)
            local money = QBX.PlayerData.money or {}
            local job = QBX.PlayerData.job or {}
            local charinfo = QBX.PlayerData.charinfo or {}
            local district = LocalPlayer.state.lotbDistrict or 'county'

            SendNUIMessage({
                action = 'update',
                visible = true,
                health = health,
                armor = armor,
                cash = money.cash or 0,
                bank = money.bank or 0,
                job = job.label or job.name or 'Civilian',
                name = ((charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')):gsub('^%s*(.-)%s*$', '%1'),
                district = district,
                talking = NetworkIsPlayerTalking(PlayerId())
            })
        end
    end
end)
