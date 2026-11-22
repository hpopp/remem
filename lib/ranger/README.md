# ranger

An HTTP/1.1 connection worker for Koja servers. A ranger owns one
accepted socket at a time and serves every request its visitor
sends, so applications keep only their accept loop and their routes.

Ranger handles:

- Keep-alive serving with a per-connection request budget
- Pipelined requests, chunked bodies, and bodies that are not UTF-8
- A body size cap, answered with 413, and a request head size cap,
  answered with 431
- Idle, read, and write timeouts, with a 408 for a request that takes
  too long to arrive
- A 400 for a request that is not valid HTTP and a 501 for an unknown
  method
- `HEAD` responses with no body
- Partial-write safe responses, so large bodies always send fully

## Usage

Spawn a `Worker` for each socket your acceptor receives:

```koja
alias Ranger.Config
alias Ranger.Worker

config = Config{handler: request -> router.dispatch(request)}

# In the acceptor process:
TCPEvent.Connected(client) ->
  _ = spawn Worker.start(Worker{client: client, config: config})
```

`Config` takes the handler, a `fn (Request) -> Response`. Every other
field has a default, and the chainable `with_` functions adjust them:

| Function                           | Default    | Purpose                                        |
| ---------------------------------- | ---------- | ---------------------------------------------- |
| `with_error_response`              | plain text | Responses for 400, 408, 413, 431, and 501      |
| `with_idle_timeout`                | 60 s       | Wait for the first byte of a request           |
| `with_max_body_bytes`              | 1 MiB      | Body cap, larger answers 413                   |
| `with_max_header_bytes`            | 16 KiB     | Request head cap, larger answers 431           |
| `with_max_requests_per_connection` | 1000       | Keep-alive request budget                      |
| `with_on_reject`                   | no-op      | Rejected request hook                          |
| `with_on_request`                  | no-op      | Access logging hook                            |
| `with_read_timeout`                | 30 s       | Time for a request to arrive, more answers 408 |
| `with_write_timeout`               | 30 s       | Time for each write of a response              |

`on_request` fires after each dispatched request with the request,
the response, and the elapsed time as a `Duration`. `on_reject` fires when
the worker rejects a request itself, before a handler could run.

A connection with no request in progress closes after the idle
timeout with no response. Each rejection closes the connection after
its response.

## Known gaps

Ranger inherits one limit from the Koja standard library. There is
no graceful drain, because `Net.TCPServer` cannot stop accepting.
