local opening = false

local function openStory()
    if opening then return end
    opening = true
    local current = lib.callback.await('lotb_identity:getStory', false) or { story = '', goals = '' }
    local input = lib.inputDialog('LAND OF THE BLOODY RP — Character Foundation', {
        { type = 'textarea', label = 'Who is your character?', description = 'History, personality, important relationships, neighborhood ties, and what shaped them.', required = true, default = current.story, min = 20, max = 700 },
        { type = 'textarea', label = 'What do they want?', description = 'Long-term goals create serious RP. Money can be one goal, but should not be the whole character.', required = true, default = current.goals, min = 10, max = 500 }
    })
    opening = false
    if not input then return end
    TriggerServerEvent('lotb_identity:saveStory', input[1] or '', input[2] or '')
end

RegisterCommand('rpstory', openStory, false)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    CreateThread(function()
        Wait(8000)
        local current = lib.callback.await('lotb_identity:getStory', false)
        if current and (not current.story or #current.story < 20) then
            lib.alertDialog({
                header = 'Welcome to Land of the Bloody RP',
                content = 'Before chasing money or a job, give the city a character it can remember. Your story and goals are private character-development context, not a public biography.',
                centered = true
            })
            openStory()
        end
    end)
end)
