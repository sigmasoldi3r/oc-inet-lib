--[[--
  Socket library
  Argochamber Interactive 2017
  Creates virtual sockets that may be used to pass messages to a bound endpoint.
--]]--
local modem = require('component').modem;
local event = require('event');

--[[--
  Export Module socket
--]]--
local socket = {};

--[[--
  Generator function creates a filter function for the modem that filters by
  port and by incoming client address.
  @param {number} portSetup
  @param {string} addressSetup
  @returns {function}
--]]--
function socket.filterIncoming(portSetup, addressSetup)
  return function(evt, _, address, port)
    return evt == 'modem_message' and port == portSetup and address == addressSetup;
  end
end

--[[--
  Generator function creates a filter-by-port filter function for the modem
  messages.
  @param {number} portSetup
  @returns {function}
--]]--
function socket.filterByPort(portSetup)
  return function(evt, _, _, port)
    return evt == 'modem_message' and port == portSetup;
  end
end

--[[--
  Crops the payload from the message header.
  @param {string} raw
  @returns {string}
--]]--
function socket.cropPayload(raw)
  return raw:sub(2, raw:len());
end

--[[--
  P
--]]--
function socket.pullEvent(filter)
  local args = {event.pullFiltered(filter)};
  return {
    event = args[1],
    localhost = args[2],
    remote = args[3],
    port = args[4],
    distance = args[5],
    message = args[6]
  };
end

--[[--
  Prototype: Socket
  @author sigmasoldier
--]]--
socket.__Socket = {};

--[[--
  Sends a message to the given endpoint, rawly.
  @param {string} msg
--]]--
function socket.__Socket:sendRaw(msg)
  modem.send(self.address, self.port, msg);
end

--[[--
  Sends a message payload chunk.
  @param {string} message
--]]--
function socket.__Socket:send(message)
  if (not self.isOpen) then
    error('Socket is closed');
  end
  self:sendRaw(table.concat{'M', message});
  local response = socket.pullEvent(self.filter);
  local h = response.message:sub(1,1);
  if (h == 'C') then
    self:clean();
    if (self.onCloseHandler) then
      self:onCloseHandler();
    end
  elseif (h == 'M') then
    return socket.cropPayload(response.message), response.distance;
  else
    error('Uncaught error: "'..h..'" is not a valid header for the packet.');
  end
end

--[[--
  Opens the socket, sends the open request signal.
  @param {function} handler
--]]--
function socket.__Socket:open()
  self:sendRaw('O');
  self.isOpen = true;
end

--[[--
  Sets the on close handler which is called if set, when the server signals
  close.
  @param {function} handler
--]]--
function socket.__Socket:onClose(handler)
  self.onCloseHandler = handler;
end

--[[--
  Closes the stream pipe.
--]]--
function socket.__Socket:close()
  self:sendRaw('C');
  self:clean();
end

--[[--
  Releases the resources of the socket like listeners...
--]]--
function socket.__Socket:clean()
  self.isOpen = false;
end

--[[--
  Constructor for Socket
--]]--
function socket.Socket(address, port)
  local self = {};

  modem.open(port);

  self.address = address;
  self.port = port;
  self.isOpen = false;
  self.filter = socket.filterIncoming(self.port, self.address);

  -- Manually set the pointers to functions:
  self.clean = socket.__Socket.clean;
  self.onClose = socket.__Socket.onClose;
  self.close = socket.__Socket.close;
  self.send = socket.__Socket.send;
  self.sendRaw = socket.__Socket.sendRaw;
  self.open = socket.__Socket.open;

  return self;
end

--[[--
  Prototype: SocketServer
  @author sigmasoldier
--]]--
socket.__SocketServer = {};

--[[--
  When ready, calls the handler and passes the new instance.
  @param {Socket} client
--]]--
function socket.__SocketServer:onReady(client)
  self.handler(client);
end

--[[--
  Listens the given port for an incoming
--]]--
function socket.__SocketServer:listen(handler)
  modem.open(self.port);
  self.handler = handler;
  local openFilter = socket.filterByPort(self.port);
  while (not self.isOpen) do
    local response = socket.pullEvent(openFilter);
    if (response.message:sub(1,1) == 'O') then
      self.address = response.remote;
      self.isOpen = true;
      local client = socket.Socket(self.address, self.port);
      client.isOpen = true;
      self:onReady(client);
    end
  end
  --[[
  local handleFilter = socket.filterIncoming(self.port, self.address);
  while (self.isOpen) do
    local response = socket.pullEvent(handleFilter);
    local h = response.message:sub(1,1);
    if (h == 'C') then
      self:clean();
      if (self.onCloseHandler) then
        self:onCloseHandler();
      end
    elseif (h == 'M') then
      self:consume(response.message, response.distance);
    else
      error('Uncaught error: "'..h..'" is not a valid header for the packet.');
    end
  end
  ]]--
end

--[[--
  Creates a socket server which listens for the specified socket.
  @param {number} port
--]]--
function socket.SocketServer(port)
  local self = {};

  modem.open(port);

  self.port = port;
  self.isOpen = false;
  self.address = false;
  self.filter = socket.filterIncoming(port);

  --Manually set the pointer to functions
  self.onReady = socket.__SocketServer.onReady;
  self.clean = socket.__Socket.clean;
  self.onClose = socket.__Socket.onClose;
  self.close = socket.__Socket.close;
  self.send = socket.__Socket.send;
  self.sendRaw = socket.__Socket.sendRaw;
  self.listen = socket.__SocketServer.listen;
  self.pullEvent = socket.__SocketServer.pullEvent;

  return self;
end

return socket;
