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
end

--[[--
  Opens the socket, sends the open request signal.
--]]--
function socket.__Socket:open(handler)
  modem.open(self.port);
  self.handler = handler;
  event.listen('modem_message', self._handler);
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
  event.ignore(self._handler);
  self.isOpen = false;
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
  Crops the payload and sends it to the client handler.
  @param {string} payload
  @param {number} distance
--]]--
function socket.__Socket:consume(payload, distance)
  self.handler(socket.cropPayload(payload), distance);
end

--[[--
  Constructor for Socket
--]]--
function socket.Socket(address, port)
  local self = {};

  self.address = address;
  self.port = port;
  self.isOpen = false;
  -- Manually set the pointers to functions:
  self.consume = socket.__Socket.consume;
  self.clean = socket.__Socket.clean;
  self.onClose = socket.__Socket.onClose;
  self.close = socket.__Socket.close;
  self.send = socket.__Socket.send;
  self.sendRaw = socket.__Socket.sendRaw;
  self.open = socket.__Socket.open;

  self._handler = function(evt, localAddr, remoteAddr, port, distance, payload)
    if (remoteAddr == address and port == self.port) then
      local h = payload:sub(1,1);
      if (h == 'C') then
        if (self.onCloseHandler) then
          self:onCloseHandler();
        end
        self:clean();
      elseif (h == 'M') then
        self:consume(payload, distance);
      else
        error('Uncaught error: "'..h..'" is not a valid header for the packet.');
      end
    end
    -- Else ignore, the message is not for this socket.
  end

  return self;
end

--[[--
  Prototype: SocketServer
  @author sigmasoldier
--]]--
socket.__SocketServer = {};

--[[--
  Listens the given port for an incoming
--]]--
function socket.__SocketServer:listen(handler)
  modem.open(self.port);
  self.handler = handler;
  event.listen('modem_message', self._handler);
end

--[[--
  Creates a socket server which listens for the specified socket.
  @param {number} port
--]]--
function socket.SocketServer(port)
  local self = {};

  self.port = port;
  self.isOpen = false;
  self.address = false;

  --Manually set the pointer to functions
  self.consume = socket.__Socket.consume;
  self.clean = socket.__Socket.clean;
  self.onClose = socket.__Socket.onClose;
  self.close = socket.__Socket.close;
  self.send = socket.__Socket.send;
  self.sendRaw = socket.__Socket.sendRaw;
  self.listen = socket.__SocketServer.listen;

  self._handler = function(evt, localAddr, remoteAddr, port, distance, payload)
    if (not self.address and payload:sub(1,1) == 'O') then
      self.address = remoteAddr;
      self.isOpen = true;
    elseif (remoteAddr == self.address and port == self.port) then
      local h = payload:sub(1,1);
      if (h == 'C') then
        self:clean();
        if (self.onCloseHandler) then
          self:onCloseHandler();
        end
      elseif (h == 'M') then
        self:consume(payload, distance);
      else
        error('Uncaught error: "'..h..'" is not a valid header for the packet.');
      end
    end
    -- Else ignore the handler.
  end

  return self;
end

return socket;
