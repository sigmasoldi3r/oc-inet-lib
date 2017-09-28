--[[
  Network message handling by argochamber interactive
  Argochamber data transfer protocol - Similar to HTTP
  No modes, only arbitrary headers.
--]]
local dns = require('dns');
local socket = require('socket');
local json = require('serialization');
local net = {};

local DEFAULT_ADTP_PORT = 80;

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
  @param {table} options
  @param {number} contentLength
--]]--
function net.parseRequestOptions(options, contentLength)
  options.port = options.port or DEFAULT_ADTP_PORT;
  options.address = dns.get(options.address) or options.address;
  options.headers = options.headers or {};
  options.headers['Content-Type'] = options.headers['Content-Type'] or 'text';
  options.headers['Content-Length'] = options.headers['Content-Length'] or contentLength or 0;
  options.rawHeaders = net.compileHeaders(options.headers);
end

--[[--
  Compiles the body for the ADTP
--]]--
function net.compileBody(options)
  return 'ADTP-1.0 '
    ..tostring(options.mode or 'GET')..' '
    ..tostring(options.code or 200)..'\n'
    ..options.rawHeaders..'\n';
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
      local k, v = rawHeader:match('(.-)=(.+)');
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
  protocol.code = p[4];
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
  local headers = net.parseHeaders(slice);
  return headers, protocol;
end

--[[--
  Creates a request to a server.
  @param {table} options
  @param {string} content
--]]--
function net.request(options, content)
  net.parseRequestOptions(options, content and content:len() or 0);
  local com = socket.Socket(options.address, options.port);
  local head = net.compileBody(options);
  com:open();
  local rhead = com:send(head);
  local headers, protocol = net.parseRequest(rhead);
  -- Start body consumption
  local body = {};
  while (com.isOpen) do
    local resp = com:send('true');
    if (resp) then
      body[#body + 1] = resp;
    end
  end
  return table.concat(body), headers, protocol;
end

local PACKET_SIZE = 8180;

--[[--
  Returns the value of the packet's size for this library.
  Gives the amount of bytes sent at maximum in each stream cycle.
  @returns {number}
--]]--
function net.getPacketSize()
  return PACKET_SIZE;
end

--[[--
  Prototype: Response.
  This class prototype is a proxy object for the socket client class.
  Allows safe chunked data transfer from server to clients, avoiding the
  problem of the packet size limit.
  @param {Socket} socket
--]]--
function net.Response(client)
  local this = {};

  function this.setHeader(_, key, value)
    client.headers = client.headers or {};
    client.headers[key] = value;
  end

  --[[--
    @override
  --]]--
  function this.close(_)
    client:close();
  end

  --[[--
    @override
  --]]--
  function this.sendRaw(_, msg)
    client:send(msg);
  end

  --[[--
    This function overrides the default socket's implementation, making it
    safer to access and use, specially if 'data' exceeds the packet size limit.
    @param {any} data
    @override
  --]]--
  function this:send(data)
    if (type(data) == 'table') then
      data = json.serialize(data);
    else
      data = tostring(data);
    end
    for i=1, data:len(), net.getPacketSize() do
      local sub;
      local offset = i ~= 1 and 1 or 0;
      if (i + net.getPacketSize() > data:len()) then
        sub = data:sub(i + offset, data:len());
      else
        sub = data:sub(i + offset, i+net.getPacketSize());
      end
      self:sendRaw(sub);
    end
  end

  return this;
end

--[[--
  class Request.
--]]--
function net.Request(headers, protocol)
  local this = {};

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
  while (true) do
    local sv = socket.SocketServer(port);
    sv:listen(function(client)
      local opts = {
        mode = 'GET',
        port = port,
        code = 200,
        headers = {}
      };
      net.parseRequestOptions(opts);
      local phead = net.compileBody(opts);
      local rhead = client:send(phead);
      local req = net.Request(net.parseRequest(rhead));
      local res = net.Response(client);
      handle(req, res);
    end);
    ---------------------------------------
    --local _, server, client, _, distance, raw = event.pullFiltered(portFilter(port));
    --local res = net.Response(server, client, port);
    --local req = net.Request(net.parseRequest(rhead));
    --handle(req, res);
  end
end

return net;
