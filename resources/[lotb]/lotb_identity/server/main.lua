RegisterNetEvent('lotb_identity:saveStory', function(story, goals)
    local source = source
    if type(story) ~= 'string' or type(goals) ~= 'string' then return end

    story = exports.lotb_core:CleanText(story, 700)
    goals = exports.lotb_core:CleanText(goals, 500)
    if #story < 20 then
        return exports.lotb_core:Notify(source, 'Give your character a little more history first.', 'error')
    end

    exports.qbx_core:SetMetadata(source, 'lotbStory', story)
    exports.qbx_core:SetMetadata(source, 'lotbGoals', goals)
    exports.qbx_core:Save(source)
    exports.lotb_core:Audit('identity', source, 'save_story', exports.lotb_core:GetCitizenId(source), {})
    exports.lotb_core:Notify(source, 'Character story saved.', 'success')
end)

lib.callback.register('lotb_identity:getStory', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return nil end
    local metadata = player.PlayerData.metadata or {}
    return {
        story = metadata.lotbStory or '',
        goals = metadata.lotbGoals or ''
    }
end)
