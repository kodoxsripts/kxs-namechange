fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name "kxs-namechange"
author "KodoXScripts"
description "Character Name Changer with NUI Interface"
version '1.0.0'

shared_scripts {
    'data/config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'locales/*.json',
}

dependencies {
    '/server:6116',
    '/onesync',
}
