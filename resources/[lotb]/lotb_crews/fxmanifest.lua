fx_version 'cerulean'
game 'gta5'

name 'lotb_crews'
author 'Land of the Bloody RP'
description 'Hidden crew heat and social influence without arcade territory UI'
version '0.3.0'

shared_script '@ox_lib/init.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}
client_script 'client/main.lua'

dependencies { 'qbx_core', 'ox_lib', 'oxmysql', 'lotb_core' }
