# conn

Composable HTTP routing for Koja. One request is one immutable `Conn` value, and every handler and middleware is a plain function from `Conn` to `Conn`.

This package is a design sketch. It lives inside auth-manager to prove the API against a real service before it becomes a standalone package. It routes parsed requests to responses and owns no sockets: a server package supplies the `HTTP.Request` and writes the `HTTP.Response`.

## Usage

```koja
alias Conn.Conn
alias Conn.Router
alias HTTP.Status

fn health(conn: Conn) -> Conn
  conn.text(Status.ok(), "healthy")
end

router = Router.new()
  .use(check_auth)
  .get("/health", health)
  .get("/sessions/:id", c -> sessions.show(c))

response = router.dispatch(request)
```

Pattern segments that start with `:` bind path parameters, read with `conn.param("id")`. The first matching route wins. Requests with no match run the fallback, replaceable with `not_found`.

## Design

- **`Conn` is a value.** Handlers transform it and return it. There is no hidden connection state, so handlers are plain functions that tests can call directly.
- **Dependencies arrive by closure capture.** `Conn` carries no application context slot. A handler that needs a store captures it when the route table is built, so each handler declares exactly what it uses.
- **Middleware and handlers share one shape**, `fn (Conn) -> Conn`. Middleware registered with `use` runs in order before the matched handler. `conn.halt()` stops the pipeline and sends the response as-is.

## Responses

`Conn` builds responses incrementally:

| Function                       | Effect                                    |
| ------------------------------ | ----------------------------------------- |
| `resp(status, body)`           | Set status and body, headers untouched.   |
| `text(status, body)`           | Plain text body with content headers.     |
| `json(status, value)`          | JSON body with content headers.           |
| `put_resp_header(name, value)` | Set one response header.                  |
| `halt()`                       | Stop the pipeline after the current step. |

`to_response` converts the accumulated state into an `HTTP.Response`. A conn that never set a status becomes a 500, because a handler forgot to respond.

## Not yet designed

- Route groups and mounted sub-routers.
- The server package boundary: who owns keep-alive, read framing, and worker processes.
- Request body streaming. `Conn.body` is the fully buffered body today.

## License

MIT
