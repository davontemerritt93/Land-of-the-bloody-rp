fx_version 'cerulean'
game 'gta5'

name 'lotb_medical'
author 'Land of the Bloody RP'
description 'Persistent serious-RP medical continuity'
version '0.3.0'

shared_script '@ox_lib/init.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}
client_script 'client/main.lua'

dependencies { 'qbx_core', 'ox_lib', 'oxmysql', 'lotb_core' }
