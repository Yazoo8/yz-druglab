fx_version 'cerulean'
game 'gta5'

author 'Yazoo'
description 'Druglab'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

files {
    'html/index.html',
    'html/drug-lab.css',
    'html/drug-lab.js',
}

ui_page 'html/index.html'

dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'es_extended',
    'oxmysql',
}
