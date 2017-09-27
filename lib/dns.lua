--[[
  DNS API by argochamber interactive 2017
  This simple API is used to store DNS table in a minimal database.
  May be used by a server, or as a local copy by a client.
]]--
local json = require('serialization');
local dns = {}; --Export API.

local LOCAL_TABLE = '.dns-table';
local BLANK_TABLE_SER = '{}';

--[[--
  Opens the table in the given mode, defaults to ascii read.
  @param {string} mode
  @returns {File}
--]]--
function dns.openDB(mode)
  local f = io.open(LOCAL_TABLE, 'r');
  if (not f) then
    io.close(f);
    local f2 = io.open(LOCAL_TABLE, 'w');
    f2:write('{}');
    f2:close();
  end
  return io.open(LOCAL_TABLE, mode or 'r');
end

--[[--
  Creates if not existing, and clears the table to a blank one.
  Returns error if present, nil otherwise.
  @returns {nil|string}
--]]--
function dns.clear()
  local file = dns.openDB('w');
  local _, err = file:write(BLANK_TABLE_SER);
  file:close();
  return err;
end

--[[--
  Recovers the local copy of the DNS table.
  Use this as a database in servers, or as an offline copy in clients.
  @returns {table}
--]]--
function dns.getAll()
  local file = dns.openDB();
  local data = file:read('*all');
  file:close();
  data = json.unserialize(data) or {};
  return data;
end

--[[--
  Writes the specified table as is.
  Returns error if present.
  @returns {nil|string}
--]]--
function dns.write(any)
  local data = json.serialize(any, true);
  local file = dns.openDB('w');
  local _, err = file:write(data);
  file:close();
  return err;
end

--[[--
  Sets a given domain to a specific address in the local DNS registry.
  @param {string} domain
  @param {string} address
  @returns {nil|string}
--]]--
function dns.set(domain, address)
  local data = dns.getAll();
  data[domain] = address;
  return dns.write(data);
end

--[[--
  Returns the address bound to the specified domain, nil if there is not.
  @param {string} domain
  @returns {string}
--]]--
function dns.get(domain)
  return dns.getAll()[domain];
end

return dns; --Expose public API.
