fx_version 'cerulean'
game 'gta5'

name 'lotb_opportunities'
author 'Land of the Bloody RP'
description 'Dynamic RP opportunity director driven by city state'
version '0.3.0'

shared_script '@ox_lib/init.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}
client_script 'client/main.lua'

dependencies { 'ox_lib', 'oxmysql', 'lotb_core', 'lotb_citymemory', 'lotb_rumors' }
