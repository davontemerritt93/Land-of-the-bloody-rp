fx_version 'cerulean'
game 'gta5'

name 'lotb_underworld'
author 'Land of the Bloody RP'
description 'Relationship-driven criminal progression, operations and crafting'
version '0.4.0'

shared_scripts {
  '@ox_lib/init.lua',
  'config/shared.lua'
}
server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/main.lua'
}
client_script 'client/main.lua'

dependencies {
  'lotb_core',
  'lotb_citymemory',
  'lotb_rumors',
  'ox_lib',
  'oxmysql',
  'ox_inventory',
  'qbx_core'
}
