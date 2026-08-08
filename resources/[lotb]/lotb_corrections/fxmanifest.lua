fx_version 'cerulean'
game 'gta5'

name 'lotb_corrections'
author 'Land of the Bloody RP'
description 'Persistent sentencing, corrections, parole and prison bridge authority'
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
