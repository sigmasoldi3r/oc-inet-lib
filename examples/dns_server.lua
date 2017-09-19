-- Require DNS api
local dns = require('dns');
local dns_remote = require('dns_remote');
local net = require('component').modem;

local f = io.open('address.txt', 'w');
f:write(net.address);
f:close();

local tbl = dns.getAll();

dns_remote.openPort();
dns_remote.listen(function(client)
  print('[DNS]: '..client);
  return tbl;
end);