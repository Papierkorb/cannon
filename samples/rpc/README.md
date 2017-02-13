# RPC example

Showcasing a simple greeter service and ping (timing) test.

## Quick Start

1. Open two terminals
2. Run `crystal server.cr` in the first one
3. Run `crystal client.cr` in the second one
4. Press Ctrl+C to stop the server afterwards

## Files

* `description.cr` contains the description module.  You'd share this file
  between your client and server applications.
* `client.cr` is a full client implementation with the client class.
* `server.cr` is a full server implementation with the service class.
