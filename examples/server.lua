-- Example of an ADTP server
local net = require('net');

local r = [[ADTP-1.0 GET Transfer
Content-Type=text
Overloped=true

Body here is, mark me down maybe.
he...
fuck this]];

net.createServer(function(request, response)
  print('Client said: "'..(request.body)..'"');
  response.send('Hi dude!');
end, 80);