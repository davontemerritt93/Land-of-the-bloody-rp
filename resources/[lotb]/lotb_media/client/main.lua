local function articleDialog(article)
    local sources = article.sources_json and json.decode(article.sources_json) or {}
    local sourceText = #sources > 0 and table.concat(sources, ', ') or 'No source list published.'
    local correction = article.correction_note and ('\n\nCORRECTION:\n' .. article.correction_note) or ''
    lib.alertDialog({
        header = article.headline,
        content = ('%s • %s%s\n\n%s\n\nSources noted by reporter: %s%s'):format(article.outlet or 'News', article.category or 'local', article.district and (' • '..article.district) or '', article.body or '', sourceText, correction),
        centered = true
    })
end

local function writeDraft(existing)
    local input=lib.inputDialog(existing and 'Edit News Draft' or 'Write News Story',{
        {type='input',label='Outlet',default=existing and existing.outlet or 'LOTB News',required=true,max=96},
        {type='input',label='Headline',default=existing and existing.headline or '',required=true,max=180},
        {type='select',label='Category',default=existing and existing.category or 'local',required=true,options={{value='local',label='Local'},{value='crime',label='Crime & Courts'},{value='business',label='Business'},{value='community',label='Community'},{value='politics',label='City Government'},{value='culture',label='Culture'},{value='investigation',label='Investigation'}}},
        {type='input',label='District (optional)',default=existing and existing.district or ''},
        {type='textarea',label='Article',default=existing and existing.body or '',required=true,min=40,max=6000},
        {type='input',label='Sources / references',description='Comma-separated source labels or RP references.',default=existing and existing.sources_json and table.concat(json.decode(existing.sources_json) or {},', ') or ''}
    })
    if input then
        TriggerServerEvent('lotb_media:saveDraft',{articleKey=existing and existing.article_key or nil,outlet=input[1],headline=input[2],category=input[3],district=input[4],body=input[5],sources=input[6] or ''})
    end
end

local function draftMenu(article)
    local options={
        {title=article.headline,description=('%s • %s'):format(article.status,article.article_key),icon='newspaper',onSelect=function() articleDialog(article) end}
    }
    if article.status=='draft' then
        options[#options+1]={title='Edit draft',icon='pen',onSelect=function() writeDraft(article) end}
        options[#options+1]={title='Publish',description='Published stories appear in the city feed.',icon='paper-plane',onSelect=function()
            local ok=lib.alertDialog({header='Publish this story?',content='Publishing makes the article public. Corrections can be attached later.',cancel=true,centered=true})
            if ok=='confirm' then TriggerServerEvent('lotb_media:publish',article.article_key) end
        end}
    elseif article.status=='published' then
        options[#options+1]={title='Attach correction',icon='pen-to-square',onSelect=function()
            local input=lib.inputDialog('Publish correction',{{type='textarea',label='Correction',required=true,min=5,max=800}})
            if input then TriggerServerEvent('lotb_media:correct',article.article_key,input[1]) end
        end}
    end
    lib.registerContext({id='lotb_draft_menu',title='Newsroom',options=options}); lib.showContext('lotb_draft_menu')
end

RegisterCommand('news',function()
    local data=lib.callback.await('lotb_media:home',false); if not data then return end
    local options={}
    if data.reporter then
        options[#options+1]={title='Write a story',description='Draft first, then publish when ready.',icon='pen-nib',onSelect=function() writeDraft(nil) end}
        options[#options+1]={title='My newsroom',description=('%s drafts/published articles'):format(#(data.drafts or {})),icon='folder-open',onSelect=function()
            local rows={}; for _,article in ipairs(data.drafts or {}) do rows[#rows+1]={title=article.headline,description=('%s • %s'):format(article.status,article.article_key),icon='file-lines',onSelect=function() draftMenu(article) end} end
            if #rows==0 then rows[1]={title='No newsroom files yet'} end
            lib.registerContext({id='lotb_newsroom_files',title='My Newsroom',options=rows}); lib.showContext('lotb_newsroom_files')
        end}
    end
    for _,article in ipairs(data.published or {}) do
        options[#options+1]={title=article.headline,description=('%s%s'):format(article.outlet or 'News',article.correction_note and ' • corrected' or ''),icon='newspaper',onSelect=function() articleDialog(article) end}
    end
    if #options==0 then options[1]={title='No published news yet'} end
    lib.registerContext({id='lotb_news',title='LOTB News',options=options}); lib.showContext('lotb_news')
end,false)
