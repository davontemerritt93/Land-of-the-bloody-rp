fx_version 'cerulean'
game 'gta5'

name 'lotb_citymemory'
author 'Land of the Bloody RP'
description 'Persistent character memory and neighborhood pulse'
version '0.3.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config/shared.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}

dependencies {
    'qbx_core',
    'ox_lib',
    'oxmysql',
    'lotb_core'
}
