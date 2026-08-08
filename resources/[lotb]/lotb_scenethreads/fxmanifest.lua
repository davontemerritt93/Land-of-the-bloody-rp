fx_version 'cerulean'
game 'gta5'

name 'lotb_scenethreads'
author 'Land of the Bloody RP'
description 'Persistent serious-RP story threads'
version '0.3.0'

shared_script '@ox_lib/init.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies { 'ox_lib', 'oxmysql', 'lotb_core' }
