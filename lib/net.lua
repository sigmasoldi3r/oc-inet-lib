--[[
  Network message handling by argochamber interactive
  Argochamber data transfer protocol - Similar to HTTP
  No modes, only arbitrary headers.
--]]
local modem = require('component').modem;
local dns = require('dns');
local event = require('event');
local net = {};

local DEFAULT_ADTP_PORT = 80;

--[[--
  Generator function that makes a port filtering function for modem messages.
  @param {number} port
  @returns {function}
--]]--
local function portFilter(filterPort)
  return function(msg, _, _, port)
    if (msg ~= 'modem_message') then
      return false;
    end;
    if (port ~= filterPort) then
      return false;
    end
    return true;
  end
end

--[[--
  Compiles headers into a single string the headers for the request.
  @param {table} headers
  @returns {string}
--]]--
function net.compileHeaders(headers)
  local tbl = {};
  for k, v in pairs(headers) do
    tbl[#tbl + 1] = table.concat({k, '=', tostring(v), '\n'});
  end
  return table.concat(tbl);
end

--[[--
  Parses request options.
--]]--
function net.parseRequestOptions(options, content)
  options.port = options.port or DEFAULT_ADTP_PORT;
  options.address = dns.get(options.address) or options.address;
  options.headers = options.headers or {};
  options.headers['Content-Type'] = options.headers['Content-Type'] or 'text';
  options.headers['Content-Length'] = options.headers['Content-Length'] or content:len();
  options.rawHeaders = net.compileHeaders(options.headers);
end

--[[--
  Compiles the body for the ADTP
--]]--
function net.compileBody(options, content)
  return 'ADTP-1.0 '..tostring(options.mode or 'GET')..' '..tostring(options.port)..'\n'..options.rawHeaders..'\n'..tostring(content);
end

--[[--
  Parses request headers and gives a length of the total body.
  The request body must have the protocol headline chopped.
  @param {string} raw
  @returns {table, number}
--]]--
function net.parseHeaders(raw)
  local i = 0;
  local buffer = {};
  local headers = {};
  for j=1, raw:len() do
    local s = raw:sub(j,j);
    if (s == '\n') then
      local rawHeader = table.concat(buffer);
      local k, v = rawHeader:match('(.-)%=(.-)');
      headers[k] = v;
      buffer = {};
      if (raw:sub(j+1, j+1) == '\n') then
        break;
      end
    else
      buffer[#buffer + 1] = s;
    end
    i = i + 1;
  end
  return headers, i;
end

--[[--
  Chops down the encoding headline and parses it, then returns the copped
  version of the body, this must be passed to net#parseHeaders(raw)
  @param {string} raw
  @returns {table, string}
--]]--
function net.parseProtocol(raw)
  local headline = raw:match('^(.-)\n');
  local protocol = {};
  local p = {headline:match('(.-)%-(.-)%s+(.-)%s+(.-)')}
  protocol.name = p[1];
  protocol.version = p[2];
  protocol.mode = p[3];
  protocol.port = p[4];
  local slice = raw:gsub('^.-\n(.*)', '%1');
  return protocol, slice;
end

--[[--
  Extracts the body from a chopped raw request body.
  This index is given by the header parser.
  @param {string} raw
  @param {number} index
  @returns {string}
--]]--
function net.getBody(raw, index)
  return raw:sub(index + 3, raw:len());
end

--[[--
  Parses the request (or response, as they're symmetric) body and headers.
  @param {string} raw
  @returns {string, table, table}
--]]--
function net.parseRequest(raw)
  local protocol, slice = net.parseProtocol(raw);
  local headers, index = net.parseHeaders(slice);
  local body = net.getBody(slice, index);
  return body, headers, protocol;
end

--[[--
  Creates a request to a server.
  @param {table} options
  @param {string} content
  @param {function} resolve
  @param {function} reject
--]]--
function net.request(options, content, resolve, reject)
  net.parseRequestOptions(options, content);
  modem.open(options.port);
  modem.send(options.address, options.port, net.compileBody(options, content));
  local _, _, _, _, _, response = event.pullFiltered(portFilter(options.port));
  local body, headers, meta = net.parseRequest(response);
  resolve(body, headers, meta);
end

--[[--
  class Response.
--]]--
function net.Response(server, client, port)
  local this = {};
  
  this.headers = {
    ['Content-Type'] = 'text',
    ['Content-Length'] = 0
  };
  
  --[[--
    Sets a response's header.
    @param {string} k
    @param {any} v
  --]]--
  function this.setHeader(k, v)
    this.headers[k] = v;
  end
  
  --[[--
    Sends the response data and ends the transaction.
    The data is compiled using request's symmetric compiler.
    @param {string} data
  --]]--
  function this.send(data)
    local options = {
      port = port,
      address = client,
      rawHeaders = net.compileHeaders(this.headers)
    };
    modem.send(client, port, net.compileBody(options, data));
  end
  
  return this;
end

--[[--
  class Request.
--]]--
function net.Request(body, headers, protocol)
  local this = {};
  
  this.body = body;
  this.headers = headers;
  this.protocol = protocol;
  
  return this;
end

--[[--
  Creates a server for ADTP transfer protocol.
  @param {function} handle
  @param {number} port
--]]--
function net.createServer(handle, port)
  port = port or DEFAULT_ADTP_PORT;
  modem.open(port);
  while (true) do
    local _, server, client, _, distance, raw = event.pullFiltered(portFilter(port));
    local res = net.Response(server, client, port);
    local req = net.Request(net.parseRequest(raw));
    handle(req, res);
  end
end

return net;