# oc-inet-lib
Opencomputers Internal networking API

* * *

This networking library includes three libraries:
- net
- dns
- dns_remote

# net

The `net` library does basic networking:


## `net.request`
For clientside request in `ADTP` protocol.

Example:
```lua
local net = require('net');

local options = {
  address = '129f880a-8889-4dc3-918c-c39d98db6f54'
}; -- Alternatively, this can be a domain.

net.request(options, 'your data', function(response)
  print('The server said: '..response);
end);
```

This function first checks if the `address` is a domain in the local domain registry.
See (dns)[#dns] library.

# dns

The `dns` library does basic DNS database storage in local computer.

```lua
local dns = require('dns');

dns.set('my-domain', '129f880a-8889-4dc3-918c-c39d98db6f54');
dns.get('my-domain'); --'129f880a-8889-4dc3-918c-c39d98db6f54'
```
Those changes persists in time.

# dns_remote

This combines a custom protocol `DNSP` DNS transfer protocol which encodes the DNS data into the network.
Usually, you set up a DNS server using the `dns_remote` library and when the client boots, makes a request
to those server asking for DNSes.

Serve DNSes:
```lua
local dns = require('dns');
local dns_remote = require('dns_remote');

local tbl = dns.getAll();

dns_remote.openPort();
dns_remote.listen(function(client)
  print('[DNS]: '..client);
  return tbl;
end);
```

Ask for DNSes: (Client)
```lua
-- The addres should be a well-known DNS server.
-- Otherwise you can set up a DNS server provider broadcaster, maybe (Not implemented yet).
local ADDR = '129f880a-8889-4dc3-918c-c39d98db6f54';

dns_remote.openPort();
dns_remote.addServer(ADDR);

local domains = dns_remote.getAllDNS();
dns.write(domains);
```
