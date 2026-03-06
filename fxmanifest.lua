fx_version 'cerulean'
game 'gta5'

name 'fivem-pedmatrix'
author 'fivem-pedmatrix Team'
description 'QBCore height synchronization resource with matrix-based scaling'
version '1.0.0'

lua54 'yes'

-- Dependencies
dependency 'oxmysql'

-- Shared
shared_script 'shared/config.lua'

-- Client
client_script 'client/main.lua'
client_script 'client/sync.lua'
client_script 'client/ui.lua'

-- Server
server_script 'server/main.lua'
server_script 'server/database.lua'

-- NUI
ui_page 'ui/index.html'

files {
    'ui/index.html'
}

-- Export for external resources
exports {
    'SetPlayerHeight',
    'GetPlayerHeight'
}
