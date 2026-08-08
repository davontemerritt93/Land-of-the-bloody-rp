fx_version 'cerulean'
game 'gta5'

name 'lotb_hud'
author 'Land of the Bloody RP'
description 'Minimal blood-red serious-RP HUD'
version '0.3.0'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js'
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua'
}

dependencies { 'qbx_core', 'lotb_citymemory' }
