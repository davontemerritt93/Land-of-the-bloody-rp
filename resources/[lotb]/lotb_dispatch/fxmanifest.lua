fx_version 'cerulean'
game 'gta5'

name 'lotb_dispatch'
author 'Land of the Bloody RP'
description 'Server-authoritative 911 and 311 dispatch'
version '0.3.0'

shared_script '@ox_lib/init.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}
client_script 'client/main.lua'

dependencies { 'qbx_core', 'ox_lib', 'oxmysql', 'lotb_core' }
