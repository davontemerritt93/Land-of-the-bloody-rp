RegisterCommand('crew', function()
    local crew = lib.callback.await('lotb_crews:mine', false)
    if not crew then
        return lib.notify({ title = 'Crew', description = 'You are not part of a registered crew.', type = 'inform' })
    end

    local pressure = (crew.heat or 0) >= 65 and 'Your crew is drawing heavy attention.' or ((crew.heat or 0) >= 30 and 'People are paying attention to your crew.' or 'Your crew is moving relatively quietly.')
    local influence = (crew.influence or 0) >= 55 and 'Your name carries weight in certain circles.' or ((crew.influence or 0) <= -25 and 'Your crew has burned important relationships.' or 'Your influence is still being established.')

    lib.alertDialog({
        header = crew.name,
        content = ('Rank: %s\n\n%s\n\n%s'):format(crew.rank_name or 'member', pressure, influence),
        centered = true
    })
end, false)
