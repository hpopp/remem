# scout

An HTTP/1.1 client for Koja. A scout keeps connections open, shares
them between processes, and puts a limit on every wait.

Scout handles:

- Keep-alive connections, with a pool of them for each origin
- `http` and `https` origins behind one client
- A limit on the connect, on the wait for a free connection, and on
  the whole request
- One more attempt for an idempotent request when the server closed
  an idle connection
- A response body size cap and a response head size cap
- Chunked response bodies and bodies that end with the connection
- One `Error` type with a `message` function

## Usage

Start one client and copy the handle into every process that makes
requests:

```koja
alias Scout.Client
alias Scout.Config

client = try Client.start()

response = try client.get("https://example.com/users/7")
response = try client.post(url, body, headers)
response = try client.send(request)

try client.stop()
```

The functions have the names and the parameter order of the one-shot
client in `HTTP`: `delete`, `get`, `head`, `options`, `patch`, `post`,
`put`, `request`, and `send`. Each one takes a trailing `timeout`
that replaces `Config.timeout` for that request:

```koja
limit = Duration.new(2, Duration.Unit.Seconds)
response = try client.get(url, Option.Some(limit))
```

Every field of `Config` has a default:

| Field              | Default      | Purpose                                        |
| ------------------ | ------------ | ---------------------------------------------- |
| `connect_timeout`  | 5 s          | Time for the TCP connect and the TLS handshake |
| `idle_timeout`     | 30 s         | Longest idle time of a connection that is used |
| `max_body_bytes`   | 16 MiB       | Response body cap                              |
| `max_header_bytes` | 16 KiB       | Response head cap                              |
| `pool_size`        | 10           | Connections for each origin                    |
| `pool_timeout`     | 5 s          | Wait for a free connection to the origin       |
| `timeout`          | 30 s         | Time for the whole request                     |
| `tls`              | system trust | Trust store and client identity for `https`    |

A request runs in the process that makes it. The client opens a
connection when a request needs one, and puts it back in the pool
when the response is complete. A response with `Connection: close`,
a response that is not HTTP/1.1, and a failed request each close
their connection.

## Errors

Every function fails with `Scout.Error`:

| Variant         | Meaning                                                      |
| --------------- | ------------------------------------------------------------ |
| `BodyTooLarge`  | The response body is larger than `max_body_bytes`            |
| `Connection`    | The network failed, with the cause from the standard library |
| `InvalidConfig` | `Client.start` rejected a `Config` field                     |
| `InvalidUrl`    | The URL cannot be requested, and no network call was made    |
| `Parse`         | The server sent bytes that are not an HTTP response          |
| `PoolTimeout`   | Every connection to the origin stayed busy                   |
| `Stopped`       | The client was stopped                                       |
| `Timeout`       | The request took longer than its limit                       |

## Retries

The client sends a request a second time in one case, and never a
third time. The case is a connection that was used before and that
fails before the first byte of a response, for an idempotent method.
The server closed that connection while it was idle.

A `POST` or a `PATCH` in that case fails with `Error.Connection`. The
caller decides if it is safe to send the request again.

## Known gaps

- HTTP/1.1 only. An `https` origin gets `http/1.1` through ALPN.
- No redirects. A 3xx is a response.
- No streamed bodies. The client reads the whole response before it
  returns.
- No upgrades. The client returns a 101 and closes the connection.
- No proxy support and no cookies.
- `timeout` does not bound the DNS lookup.
- The client opens a connection for a request that needs one, but it
  does not close an idle connection until a request finds it or the
  client stops.
