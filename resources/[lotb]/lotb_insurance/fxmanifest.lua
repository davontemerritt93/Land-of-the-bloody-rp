fx_version 'cerulean'
game 'gta5'

name 'lotb_insurance'
author 'Land of the Bloody RP'
description 'Persistent insurance policies, evidence-backed claims and adjuster review'
version '0.5.0'

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
  'lotb_properties',
  'ox_lib',
  'oxmysql',
  'qbx_core',
  'qbx_vehicles'
}
