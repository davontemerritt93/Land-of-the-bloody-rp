fx_version 'cerulean'
game 'gta5'

name 'lotb_civicwork'
author 'Land of the Bloody RP'
description 'Dynamic civilian public works driven by neighborhood conditions'
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
  'ox_lib',
  'oxmysql',
  'qbx_core'
}
