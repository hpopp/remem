# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- OpenTelemetry tracing behind `OTEL_EXPORTER_OTLP_ENDPOINT`. Each
  request runs in a server span that continues an incoming
  `traceparent`, with child spans for the database phase, embedding
  requests, and MCP tool calls. Spans export as OTLP/JSON over HTTP
  in batches. Responses carry a `traceparent` header and access log
  lines start with the trace id when tracing is on.
- `lib/open_telemetry`, the tracing package behind the above, with
  W3C context propagation, closure-scoped spans, and a batching
  exporter process.
- `Conn.assigns` for request-scoped values, with `assign`,
  `assigned`, and `Router.dispatch_conn`.
- `design/OBSERVABILITY.md`, the design for runtime-owned trace
  context, logging, and metrics in Koja.
- Structured logging behind `GCP_PROJECT_ID`. When it is set, every
  log line is one Cloud Logging JSON object with `severity`,
  `message`, and `time`. Access lines carry the method, path,
  status, and latency in `httpRequest`, and error lines carry the
  Error Reporting `@type` and a `serviceContext` named by
  `GCP_SERVICE_NAME`. Without it, lines stay text. `LOG_LEVEL` sets
  the floor.
- `lib/log`, the logging package behind the above, with a `Logger`
  value, leveled calls, attribute maps, and text and GCP formatters.

### Changed

- Logging goes through a `Logger` value built at startup and passed
  to the code that logs, in place of the static `Log` struct.

### Fixed

- The startup log names the running version again.

## [0.4.0] - 2026-09-23

### Changed

- Requires Koja 0.19. `unless` is gone from the sources, tests use
  `test` blocks with `assert`, and elapsed times flow through the
  new `Duration` and `Instant` types.
- postgres-koja 0.4.0.
- Access log durations pick their unit from the size, so a request
  logs as `452µs`, `3ms`, or `1.2s`.
- Log timestamps come from the standard library ISO 8601 renderer
  and carry microseconds, as in `2026-09-23T13:13:57.586073Z`.

### Removed

- The hand-rolled `Log.iso8601` calendar conversion.

## [0.3.2] - 2026-09-14

### Fixed

- The database pool now drops connections that come back closed or
  mid-transaction and refills the slot, so a Postgres restart no
  longer leaves broken sockets in the pool until the pod restarts.
  When Postgres is down, refills retry with backoff instead of
  shrinking the pool.

### Changed

- postgres-koja 0.3.1, which tracks connection and transaction state.

## [0.3.1] - 2026-09-07

### Fixed

- Images built by CI no longer crash on nodes without AVX-512, via the
  koja 0.18.3 toolchain.

## [0.3.0] - 2026-09-02

### Added

- `merge_entities` folds one entity into another, moving observations
  and relations, via MCP and `POST /entities/:name/merge`.
- `rename_entity` renames an entity in place, via MCP and
  `PATCH /entities/:name`.
- `list_entities` returns every entity with its observation count and
  no observations, via MCP and `GET /entities`.
- `create_entity` refuses names close to an existing entity unless
  `confirm` is true.
- A background backfill embeds observations that have no embedding
  yet, at boot and once a minute after.

### Changed

- Search ranks individual observations instead of whole entities and
  returns each entity with only the observations that matched.
- `GET /entities` returns entities without their observations and
  includes an observation count.
- Adding observations embeds only the new rows, so large entities no
  longer re-embed everything on every write.

### Fixed

- Entities with more than about 8K tokens of observations no longer
  lose their newest facts from semantic search.

## [0.2.1] - 2026-09-02

### Changed

- Successful health checks no longer write an access log line.

### Fixed

- MCP `search_memory` responses no longer take over a minute to
  render, via the koja 0.18.2 toolchain.

## [0.2.0] - 2026-09-01

### Added

- Request size caps. Headers over 16 KiB and bodies over 1 MiB get a
  413 response.
- A background sweeper deletes search log rows older than 90 days.
- Requests that match a route with the wrong method get a 405 response.
- Keep-alive connections close after a budget of 1000 requests.

### Changed

- API key auth now runs as router middleware and rejects bad
  credentials before the server checks out a database connection.
- The koja 0.18.1 toolchain cuts large response render times from
  about 15 seconds to under 1 second.
- The route table now runs on the vendored conn router, with handlers
  split into controller modules.
- HTTP connection handling moved into trail, a new vendored library
  for keep-alive serving and request framing.
- The MCP serverInfo response now reports the application version
  instead of a hardcoded string.

### Fixed

- Large responses no longer truncate. The server now retries partial
  socket writes until the full body sends.

## [0.1.0] - 2026-09-01

Initial release.

[0.3.1]: https://github.com/hpopp/remem/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/hpopp/remem/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/hpopp/remem/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/hpopp/remem/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/hpopp/remem/releases/tag/v0.1.0
