RegisterCommand('rumors',function()
    local rows=lib.callback.await('lotb_rumors:hear',false) or {}
    if #rows==0 then return lib.notify({title='Word on the street',description='Nothing credible is reaching you right now.',type='inform'}) end
    local options={}
    for _,r in ipairs(rows) do
        local certainty=(r.confidence or 0)>=75 and 'sounds solid' or ((r.confidence or 0)>=45 and 'might be true' or 'sounds shaky')
        options[#options+1]={title=r.subject,description=('%s — %s'):format(r.body,certainty),icon='comments'}
    end
    lib.registerContext({id='lotb_rumors_ctx',title='Word on the street',options=options}); lib.showContext('lotb_rumors_ctx')
end,false)
