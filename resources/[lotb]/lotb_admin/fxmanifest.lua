fx_version 'cerulean'
game 'gta5'

name 'lotb_admin'
author 'Land of the Bloody RP'
description 'Staff audit, moderation notes and lightweight admin panel'
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
  'qbx_core'
}
