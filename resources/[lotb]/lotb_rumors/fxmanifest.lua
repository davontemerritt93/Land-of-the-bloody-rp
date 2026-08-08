fx_version 'cerulean'
game 'gta5'

name 'lotb_rumors'
author 'Land of the Bloody RP'
description 'Decaying information network with confidence instead of omniscient alerts'
version '0.3.0'

shared_script '@ox_lib/init.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}
client_script 'client/main.lua'

dependencies {
    'lotb_core',
    'ox_lib',
    'oxmysql',
    'qbx_core'
}
