fx_version 'cerulean'
game 'gta5'

name 'lotb_autos'
author 'Land of the Bloody RP'
description 'Dealership inventory and audited vehicle sales using qbx_vehicles'
version '0.4.0'

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
  'qbx_core',
  'qbx_vehicles'
}
