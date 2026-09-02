# trail

An HTTP/1.1 connection worker for Koja servers. Trail owns one
accepted socket at a time and serves it correctly, so applications
keep only their accept loop and their routes.

Trail handles:

- Keep-alive serving with a per-connection request budget
- Byte-correct framing, including pipelined requests and non-ASCII
  bodies
- Header and body size caps, answered with 413
- Partial-write safe responses, so large bodies always send fully

## Usage

Spawn a `Worker` for each socket your acceptor receives:

```koja
alias Trail.Config
alias Trail.Worker

config = Config.new(request -> router.dispatch(request))

# In the acceptor process:
TCPEvent.Connected(client) ->
  _ = spawn Worker.start(Worker{client: client, config: config})
```

`Config.new` takes the handler, a `fn (Request) -> Response`. The
chainable `with_` functions adjust the rest:

| Function                           | Default    | Purpose                          |
| ---------------------------------- | ---------- | -------------------------------- |
| `with_max_body_bytes`              | 1 MiB      | Body cap, larger answers 413     |
| `with_max_header_bytes`            | 16 KiB     | Header cap, larger answers 413   |
| `with_max_requests_per_connection` | 1000       | Keep-alive request budget        |
| `with_error_response`              | plain text | Bodies for 400 and 413 responses |
| `with_on_request`                  | no-op      | Access logging hook              |
| `with_on_reject`                   | no-op      | Rejected request hook            |

`on_request` fires after each dispatched request with the request,
the response, and the elapsed milliseconds. `on_reject` fires when
the worker rejects a request itself, before a handler could run.

## Known gaps

Trail inherits two limits from the Koja standard library. There is
no graceful drain, because `Net.TCPServer` cannot stop accepting,
and no read deadline, so a client can hold a connection open
without sending a complete request.
