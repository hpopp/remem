# Log

Leveled structured logging for [Koja](https://github.com/koja-lang/koja).
A `Logger` value carries a level floor, a formatter, and bound
attributes. Two formatters ship with the package: a text format for
development and a JSON format that Google Cloud Logging reads as
structured entries.

Koja has no global mutable state, so there is no `Log.configure` and
no static `Log.info`. The application builds one `Logger` at boot and
passes it to the code that logs. The runtime-owned design that removes
this is described in `design/OBSERVABILITY.md` at the root of this
repository.

## Features

- `Debug`, `Info`, `Warn`, and `Error` levels with a floor on the logger
- Attribute maps as plain map literals
- `with` to bind attributes onto every later record
- A text format, one line per record with `key=value` fields
- A Google Cloud Logging format with `severity`, `time`, `httpRequest`,
  and Error Reporting fields
- A pluggable sink, stdout by default

## Installation

Add the package to your `koja.toml`:

```toml
[dependencies]
log = { path = "lib/log" }
```

## Usage

```koja
alias Log.Attribute
alias Log.Config as LogConfig
alias Log.GCP
alias Log.Level
alias Log.Logger
alias Log.Text

formatter =
  match settings.gcp_project_id
    Option.Some(project_id) ->
      GCP.formatter(GCP.Config{
        project_id: project_id,
        service_name: "remem",
        service_version: "0.5.0",
      })

    Option.None ->
      Text.formatter()
  end

log = Logger.new(LogConfig{formatter: formatter, level: Level.Info})

log.info("listening", ["port": Attribute.from(port)])

job = log.with(["job": "cleaner"])
job.warn("sweep skipped, pool busy")
```

Literals convert to `Attribute` on their own. A variable needs
`Attribute.from`.

`Log.elapsed(duration)` renders a duration the way `koja test` does,
as `452µs`, `3ms`, or `1.2s`, for use in a message.

## Formats

The text format writes one line per record:

```
2026-09-23T20:00:00.123456Z INFO swept 12 rows job=cleaner
```

The GCP format writes one JSON object per record. The GKE logging
agent lifts `severity`, `message`, and `time` onto the log entry and
places every other field under `jsonPayload`.

```json
{
  "severity": "INFO",
  "message": "GET /entities 200 12ms",
  "time": "2026-09-23T20:00:00.123456Z",
  "httpRequest": {
    "requestMethod": "GET",
    "requestUrl": "/entities",
    "status": 200,
    "latency": "0.012000s"
  }
}
```

Four attributes fold into the `httpRequest` field, so Logs Explorer
renders access lines as requests:

| Attribute                      | Field           | Type              |
| ------------------------------ | --------------- | ----------------- |
| `http.request.method`          | `requestMethod` | String            |
| `url.path`                     | `requestUrl`    | String            |
| `http.response.status_code`    | `status`        | Int               |
| `http.server.request.duration` | `latency`       | Int, microseconds |

`Error` records also carry the Error Reporting `@type` and a
`serviceContext` built from `GCP.Config`, so they appear in Error
Reporting without a stack trace.

The package reads no environment variables. The application decides
the level and the format and passes them in `Config`.
