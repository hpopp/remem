# OpenTelemetry

OpenTelemetry export for [Koja](https://github.com/koja-lang/koja).
Parses and writes W3C `traceparent` headers and ships the spans the
stdlib `Trace` records to a collector as OTLP/JSON over HTTP.

The stdlib owns the spans. `Trace.root` and `Trace.span` open them,
the runtime carries the context on every message, and finished
records queue in `Trace.Export`. This package is the wire side: the
codec at the HTTP boundary and the process that drains the queue.

## Features

- `Propagation.parse` and `Propagation.header` for W3C Trace Context
- An exporter process that drains `Trace.Export` on a timer and never
  touches the request path
- OTLP/JSON export to `<endpoint>/v1/traces`, or any exporter closure
- A no-op exporter when no endpoint is configured

## Installation

Add the package to your `koja.toml`:

```toml
[dependencies]
open_telemetry = { path = "lib/open_telemetry" }
```

## Usage

```koja
alias OpenTelemetry.Config as ExporterConfig
alias OpenTelemetry.Exporter
alias OpenTelemetry.Propagation

exporter = Exporter.start(ExporterConfig{
  endpoint: Option.Some("http://otel-collector:4318"),
  service_name: "remem",
  service_version: Option.Some("0.7.0"),
})
```

At the boundary, continue the caller's trace when it sent one and
start a fresh one otherwise. `Propagation.parse` turns the header into
the `Trace.Parent` that `Trace.RootOptions` carries, and no parent
starts a fresh trace. The root ignores the context the worker carries,
so a worker that serves many requests needs no reset between them.

```koja
parent = request.headers.get(Propagation.HEADER).then(h -> Propagation.parse(h).ok())

response = Trace.root(
  "GET /entities",
  Trace.RootOptions{kind: Trace.SpanKind.Server, parent: parent},
  fn (span: Trace.Span) -> Response
    response = handle(request)
    span.attribute("http.response.status_code", response.status.code)
    response
  end,
)
```

Code below the boundary opens children with `Trace.span` and needs no
context argument. An outgoing request carries the current context as
a header:

```koja
headers = Headers.new().set(Propagation.HEADER, Propagation.header(Trace.current()))
```

The package reads no environment variables. The application decides
where the endpoint comes from and passes it in `Config`.

## Export failures

Every `flush_ms` the exporter pops the finished spans and POSTs them
in batches of at most `max_batch`. A batch that the collector refuses
is dropped. The exporter warns on stderr once, then stays quiet until
an export succeeds again. When the runtime queue fills before a drain,
the runtime drops the newest records and the exporter warns with the
count it lost.
