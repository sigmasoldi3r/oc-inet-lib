-- Install script for inet libraries 1.0-beta
-- Argochamber Interactive 2017
local fs = require('filesystem');
local inet = require('component').internet;
if (not inet) then
  error('FATAL! Web installer requires internet access!');
end
if (not inet.isHttpEnabled()) then
  error('FATAL! Web installer requires HTTP to be enabled!');
end

local VERSION = '1.0.1-b';

print('Setting up the environment...');
fs.makeDirectory('usr/lib');

print('Loading web assets...');
local files = {
  ['dns.lua'] = 'https://raw.githubusercontent.com/sigmasoldi3r/oc-inet-lib/master/lib/dns.lua',
  ['dns_remote.lua'] = 'https://raw.githubusercontent.com/sigmasoldi3r/oc-inet-lib/master/lib/dns_remote.lua',
  ['net.lua'] = 'https://raw.githubusercontent.com/sigmasoldi3r/oc-inet-lib/master/lib/net.lua',
  ['socket.lua'] = 'https://raw.githubusercontent.com/sigmasoldi3r/oc-lan/master/lib/socket.lua'
};

print('Downloading files...');
local shell = require('shell');

local lib = '/usr/lib/';
for name, data in pairs(files) do
  io.write(name..' >> ');
  local rvar = ('wget -f \''..data..'\' '..lib..name);
  shell.execute(rvar);
end

print('Installation successful! Installed inet '..VERSION);
