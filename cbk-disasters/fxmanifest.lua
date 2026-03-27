fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'CowBoyKeno'
name 'cbk-disasters'
description 'Server-authoritative RP disaster system for public FiveM servers'
version '1.0.0'

shared_scripts {
    'shared/config.lua',
    'shared/disasters.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/config.lua',
    'server/main.lua'
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/script.js'
}
