# OpenTelemetry

OpenTelemetry tracing for [Koja](https://github.com/koja-lang/koja).
Parses and writes W3C `traceparent` headers, records closure-scoped
spans, and ships them to a collector as OTLP/JSON over HTTP.

The package passes span context explicitly. The runtime-owned
context slot that removes this is described in
`design/OBSERVABILITY.md` at the root of this repository.

## Features

- `Propagation.parse` and `Propagation.header` for W3C Trace Context
- Closure-scoped spans with `Server`, `Client`, and `Internal` kinds
- Attribute maps as plain map literals
- A tracer process that batches by count or timer and never blocks callers
- OTLP/JSON export to `<endpoint>/v1/traces`, or any exporter closure
- A no-op tracer when no endpoint is configured

## Installation

Add the package to your `koja.toml`:

```toml
[dependencies]
open_telemetry = { path = "lib/open_telemetry" }
```

## Usage

```koja
alias OpenTelemetry.Attribute
alias OpenTelemetry.Config as TracerConfig
alias OpenTelemetry.Propagation
alias OpenTelemetry.SpanKind
alias OpenTelemetry.Tracer

tracer = Tracer.start(TracerConfig{
  endpoint: Option.Some("http://otel-collector:4318"),
  service_name: "remem",
  service_version: Option.Some("0.5.0"),
})

# Continue the caller's trace when it sent one.
parent = Propagation.parse(header) rescue _ -> Option.None

attributes: Map<String, Attribute> = [
  "http.method": "GET",
  "http.route": Attribute.from(route),
]

response = tracer.span("GET /entities", SpanKind.Server, parent, attributes, ctx ->
  handle(request, ctx))
```

The closure receives the span's own context. Pass it to child spans
as their parent, and to outgoing requests as a header:

```koja
headers = Headers.new().set(Propagation.HEADER, Propagation.header(ctx))
```

`span_result` marks the span as an error when the closure returns
`Err`. `span_with` lets the closure add attributes and a status it
learns while it runs, such as an HTTP response code.

The package reads no environment variables. The application decides
where the endpoint comes from and passes it in `Config`.

## Export failures

A batch that the collector refuses is dropped. The tracer warns on
stderr once, then stays quiet until an export succeeds again. Tracing
never costs the request path more than a cast.
