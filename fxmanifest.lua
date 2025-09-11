fx_version 'cerulean'
game 'rdr3'

author 'The Rift Trails'
description 'Custom race script for the rift trails'
version '0.0.1'


shared_scripts {
  'shared/config.lua'
}

client_scripts {
  'client/main.lua'
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/main.lua'
}