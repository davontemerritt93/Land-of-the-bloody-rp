fx_version 'cerulean'
game 'gta5'

name 'lotb_media'
author 'Land of the Bloody RP'
description 'Player journalism, corrections and public news tied to city history'
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
