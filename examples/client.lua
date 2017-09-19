-- This emulates the boot
local dns_remote = require('dns_remote');
local dns = require('dns');
local net = require('net');

--[[
local ADDR = '129f880a-8889-4dc3-918c-c39d98db6f54';

dns_remote.openPort();
dns_remote.addServer(ADDR);

local domains = dns_remote.getAllDNS();
dns.write(domains);
]]

net.request({
  address = 'argochamber.com'
}, 'hello!', function(response)
  print('Server said: "'..response..'"');
end);