fx_version 'cerulean'
game 'gta5'

name 'lotb_cityapp'
author 'Land of the Bloody RP'
description 'Unified city-services dashboard and future phone integration bridge'
version '0.5.0'

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
