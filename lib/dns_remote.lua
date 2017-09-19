--[[
  Remote DNS handler by argochamber interactive
  Setup a server, then use this as a main DNS inter-exchange protocol.
  This simple API gets and sends messages to a remote server in order to keep
  track of the domains registered.
  You can set up any number of dns servers that you wish on the client side.
  This comes with a default configured port that can be setted up.
--]]
local net = require('component').modem;
local json = require('serialization');
local event = require('event');
local dns_remote = {};

--Default Argochamber DNS port
local DEFAULT_PORT = 8844;
local DEFAULT_TIMEOUT = 4;
local MSG_AQUIRE = '::AQUIRE-DNS-TABLE{0}';

local port = DEFAULT_PORT;
local servers = {};

--[[----------------------------------------------------------------------------
      
      THE CLIENT API
      
--]]----------------------------------------------------------------------------

--[[--
  This function will filter events that ONLY correspond to the Argochamber DNS
  transmission protocol.
  @param {string} name
  @param {string} iport
--]]--
local function filterModemEvent(name, _, _, iport)
  if (name ~= 'modem_message') then
    return false;
  end
  if (iport ~= port) then
    return false;
  end
  return true;
end

--[[--
  Pulls a DNS protocol message and parses it.
  This operation is SYNCHRONOUS, the thread is halted in the mean time, handle
  with care.
  If a message is being pulled without an incoming response the command will
  fail with a timeout.
  Returns the DNS table parsed and the host address.
  @param {number} timeout
  @returns {table, string}
--]]--
function dns_remote.pullDNSResponse(timeout)
  local _, _, server, _, _, data = event.pullFiltered(timeout or DEFAULT_TIMEOUT, filterModemEvent);
  data = json.unserialize(data);
  return data, server;
end

--[[--
  Sets the port that will be used for the DNS remote protocol.
  @param {number} newPort
--]]--
function dns_remote.setPort(newPort)
  port = newPort or port;
end

--[[--
  Opens the port if not opened yet.
--]]--
function dns_remote.openPort()
  net.open(port);
end

--[[--
  Adds a new server address to the registry.
  On the client side is recomended to use a configuration storage in order to
  persist those.
  @param {string} server raw HEX address
--]]--
function dns_remote.addServer(server)
  servers[server] = true;
end

--[[--
  Sends a message to a remote server, the next operation should be the response
  message pulling.
  @param {string} server raw HEX address
--]]--
function dns_remote.sendDNSRequest(server)
  net.send(server, port, MSG_AQUIRE);
end

--[[--
  Gets the DNS table from an specific DNS server using Argochamber DNS protocol.
  This operation is SYNCHRONOUS! This means that will halt the thread.
  @param {string} server
  @returns {table}
--]]--
function dns_remote.getDNSFromServer(server)
  dns_remote.sendDNSRequest(server);
  return dns_remote.pullDNSResponse();
end

--[[--
  Gets all Domain names from the DNS server list.
  The overlapping domain names may be overwritten randomly, be ware!
  If it is the case, a rejection table is aditionally created, showing the
  colliding domains that you may filter.
  @returns {table, table} DNS list, colliding DNSes.
--]]--
function dns_remote.getAllDNS()
  local colliding = {};
  local data = {};
  for server in pairs(servers) do
    colliding[server] = {};
    local list = dns_remote.getDNSFromServer(server);
    for k, v in pairs(list) do
      if (data[k]) then
        colliding[server][k] = data[k];
      end
      data[k] = v;
    end
  end
  return data, colliding;
end

--[[----------------------------------------------------------------------------
      
      THE SEVER API
      
--]]----------------------------------------------------------------------------

--[[--
  This function will filter events that ONLY correspond to the Argochamber DNS
  transmission protocol.
  @param {string} name
  @param {string} iport
--]]--
local function filterServerModemEvent(name, _, _, iport, _, msg)
  if (name ~= 'modem_message') then
    return false;
  end
  if (iport ~= port) then
    return false;
  end
  if (msg ~= MSG_AQUIRE) then
    return false;
  end
  return true;
end

--[[--
  Pulls a DNS protocol message, then starts a response to that client in order
  to make them know the dns that we have.
  This operation is SYNCHRONOUS, the thread is halted in the mean time, handle
  with care.
  @returns {string}
--]]--
function dns_remote.pullDNSRequest()
  local _, _, client= event.pullFiltered(filterServerModemEvent);
  return client;
end

--[[--
  Listens to a single DNS message, then uses the given function to respond them
  with data.
  This is a raw request handler but filtered to argochamber protocol.
  No request data but the client is provided since is not needed (All requests
  will send only the default aquire message).
  The callback function is an external provider of DNS names, also may be used
  as a filtering, blacklisting or whitelisting.
  @param {function} callback
--]]--
function dns_remote.await(callback)
  local client = dns_remote.pullDNSRequest();
  local data = callback(client);
  data = json.serialize(data);
  net.send(client, port, data);
end

--[[--
  Listens forever for the incoming messages so it can handle requests.
  @param {function} callback
--]]--
function dns_remote.listen(callback)
  while true do
    dns_remote.await(callback);
  end
end

return dns_remote;