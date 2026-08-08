fx_version 'cerulean'
game 'gta5'

name 'lotb_economy'
author 'Land of the Bloody RP'
description 'Audited player banking and economy hooks'
version '0.3.0'

shared_script '@ox_lib/init.lua'
server_script 'server/main.lua'
client_script 'client/main.lua'

dependencies { 'qbx_core', 'ox_lib', 'lotb_core' }
