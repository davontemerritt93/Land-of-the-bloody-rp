fx_version 'cerulean'
game 'gta5'

name 'lotb_finance'
author 'Land of the Bloody RP'
description 'Personal overview, business banking and accountable ledgers'
version '0.4.0'

shared_script '@ox_lib/init.lua'
server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/main.lua'
}
client_script 'client/main.lua'

dependencies {
  'lotb_core',
  'lotb_businesses',
  'ox_lib',
  'oxmysql',
  'qbx_core'
}
