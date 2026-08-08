fx_version 'cerulean'
game 'gta5'

name 'lotb_properties'
author 'Land of the Bloody RP'
description 'Persistent property ownership, access, maintenance and neighborhood hooks'
version '0.4.0'

shared_script '@ox_lib/init.lua'
server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/main.lua'
}
client_script 'client/main.lua'

dependencies {
  'lotb_core',
  'lotb_citymemory',
  'ox_lib',
  'oxmysql',
  'qbx_core'
}
