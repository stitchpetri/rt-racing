fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

author 'The Rift Trails'
description 'Custom race script for the rift trails'
version '0.0.1'


shared_scripts {
  'shared/config.lua'
}


server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/vorp_utils.lua',
  'server/main.lua'
}

client_scripts {
  'client/blips.lua',
  'client/main.lua'
}
