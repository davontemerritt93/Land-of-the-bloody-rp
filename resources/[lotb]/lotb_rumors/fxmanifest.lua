fx_version 'cerulean'
game 'gta5'

name 'lotb_rumors'
author 'Land of the Bloody RP'
description 'Decaying information network with confidence instead of omniscient alerts'
version '0.2.0'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}

dependencies {
    'lotb_core',
    'oxmysql',
    'qbx_core',
}
