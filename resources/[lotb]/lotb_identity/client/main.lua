RegisterCommand('rpstory', function()
    local current = lib.callback.await('lotb_identity:getStory', false) or { story = '', goals = '' }
    local input = lib.inputDialog('Character Story', {
        { type = 'textarea', label = 'Who is your character?', description = 'History, personality, important relationships, and what shaped them.', required = true, default = current.story, min = 20, max = 700 },
        { type = 'textarea', label = 'What do they want?', description = 'Long-term goals create better serious RP than grinding money.', required = false, default = current.goals, max = 500 }
    })
    if not input then return end
    TriggerServerEvent('lotb_identity:saveStory', input[1] or '', input[2] or '')
end, false)
