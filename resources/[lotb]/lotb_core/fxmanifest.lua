fx_version 'cerulean'
game 'gta5'

name 'lotb_core'
author 'Land of the Bloody RP'
description 'Shared security, audit and identity helpers'
version '0.2.0'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config/shared.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
}
