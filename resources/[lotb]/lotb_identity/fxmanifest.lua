fx_version 'cerulean'
game 'gta5'

name 'lotb_identity'
author 'Land of the Bloody RP'
description 'Character story, goals, and roleplay identity'
version '0.3.0'

shared_script '@ox_lib/init.lua'
server_script 'server/main.lua'
client_script 'client/main.lua'

dependencies { 'qbx_core', 'ox_lib', 'lotb_core' }
