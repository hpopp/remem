# remem

[![CI](https://github.com/hpopp/remem/actions/workflows/ci.yml/badge.svg)](https://github.com/hpopp/remem/actions/workflows/ci.yml)
[![GitHub Release](https://img.shields.io/github/v/release/hpopp/remem)](https://github.com/hpopp/remem/releases)

A memory graph API in written in [Koja](https://kojalang.org). remem stores named entities,
timestamped observations about them, and typed relations between them, backed by
PostgreSQL with pgvector. Search combines semantic ranking
(nomic-embed-text embeddings, cosine distance) with trigram fuzzy
name matching, merged by Reciprocal Rank Fusion.

## Run it

Start the local stack, then the service:

```
docker compose up -d
koja run
```

The compose stack provides PostgreSQL with pgvector on port 5435 and
a Text Embeddings Inference server with nomic-embed-text-v1.5 on
port 8081. Schema migrations run at startup.

## Configuration

Environment variables, with defaults that match the compose stack:

| Variable                      | Default                 | Purpose                          |
| ----------------------------- | ----------------------- | -------------------------------- |
| `PORT`                        | `8080`                  | HTTP listen port                 |
| `DB_HOST`                     | `127.0.0.1`             | PostgreSQL host                  |
| `DB_PORT`                     | `5435`                  | PostgreSQL port                  |
| `DB_USER`                     | `postgres`              | PostgreSQL user                  |
| `DB_PASSWORD`                 | none                    | PostgreSQL password              |
| `DB_NAME`                     | `remem`                 | Database name                    |
| `DB_STATEMENT_CACHE`          | `256`                   | Driver statement cache size      |
| `EMBEDDING_URL`               | `http://127.0.0.1:8081` | TEI embedding server             |
| `API_KEY`                     | none                    | When set, require bearer auth    |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | none                    | When set, export traces (OTLP)   |
| `OTEL_SERVICE_NAME`           | `remem`                 | Service name on exported spans   |
| `GCP_PROJECT_ID`              | none                    | When set, log Cloud Logging JSON |
| `GCP_SERVICE_NAME`            | `remem`                 | Service name on error log lines  |
| `LOG_LEVEL`                   | `info`                  | Lowest level that is logged      |

When `API_KEY` is set, every route except `GET /health` requires an
`Authorization: Bearer <key>` header.

When `GCP_PROJECT_ID` is set, every log line is one JSON object in
the shape Google Cloud Logging reads: `severity`, `message`, and
`time`, with any other fields under `jsonPayload`. Access lines put
the method, path, status, and latency in `httpRequest`, and error
lines carry the Error Reporting `@type` with a `serviceContext` of
`GCP_SERVICE_NAME` and the running version. Without it, lines are
text for a terminal. `LOG_LEVEL` accepts `debug`, `info`, `warn`, or
`error`.

When `OTEL_EXPORTER_OTLP_ENDPOINT` names an OTLP/HTTP collector,
every request runs in a server span that continues the caller's
`traceparent`, with child spans for the database phase, embedding
requests, and MCP tool calls. The response carries the server span
as a `traceparent` header and the access log line starts with the
trace id. `GET /health` is not traced.

## API

| Route                                 | Purpose                                   |
| ------------------------------------- | ----------------------------------------- |
| `GET /health`                         | Liveness plus a database probe            |
| `GET /graph`                          | Every entity and relation                 |
| `GET /entities?limit=&offset=`        | Entity summaries, most observations first |
| `POST /entities`                      | Create from `{name, type, observations?}` |
| `GET /entities/:name`                 | One entity with its relations             |
| `PATCH /entities/:name`               | Rename from `{name}`                      |
| `DELETE /entities/:name`              | Delete an entity, relations cascade       |
| `POST /entities/:name/merge`          | Fold into another entity from `{into}`    |
| `POST /entities/:name/observations`   | Append observations                       |
| `DELETE /entities/:name/observations` | Remove matching observations              |
| `POST /relations`                     | Create from `{from, to, type}`            |
| `DELETE /relations`                   | Delete the same shape                     |
| `GET /search?q=&limit=`               | Hybrid semantic and fuzzy search          |

Entity names are unique, and relations address entities by name.
Requests carry observations as plain strings. Responses return them
as rows with their own timestamps:

```json
{ "content": "...", "created_at": "...", "updated_at": "..." }
```

Entities, observations, and relations all carry `created_at` and
`updated_at`. An observation change also touches its entity's
`updated_at`. Errors return `{"error", "message", "status"}`.

`GET /entities` returns each entity without its observations and
adds an `observation_count`, so the whole graph fits in one page.
Fetch `GET /entities/:name` for the observations.

### Curation

`POST /entities` refuses a name that is trigram-similar to an
existing entity, or equal ignoring case, and names the matches in
the error. Send `"confirm": true` in the body to create it anyway.

`POST /entities/:name/merge` folds the named entity into the one in
`{"into": "..."}` and deletes it. Observations move with their
timestamps, except ones the target already holds word for word.
Relations rewire to the target, except ones that would become
self-loops or duplicate an existing relation. The whole merge runs
in one transaction.

`PATCH /entities/:name` renames an entity. Relations follow, since
they reference ids. The new name must not be taken.

### Search

`GET /search` embeds the query, ranks observations by cosine
distance against their embeddings, ranks entity names by trigram
similarity, and merges both lists with Reciprocal Rank Fusion. Hits
group by entity, where an entity's score is its best observation
plus its name match. Each result carries the entity's name and type,
its score, and up to five matching observations with their own
scores. `limit` counts entities. When the embedding server is down,
search degrades to fuzzy name ranking alone and results carry no
observations.

Each observation embeds on its own, under the text
`name (type): content`, so an entity with hundreds of facts ranks
by its most relevant fact rather than by an average of all of them.
Writes embed only the rows they insert. When the embedding server
is unreachable, the write still succeeds and a background backfill
embeds the rows once the server answers. The backfill also runs at
boot, which covers the migration to per-observation embeddings, and
after a merge or rename, which changes the entity name in the
embedding text.

Every search also appends its query to a `search_log` table. Nothing
reads the log yet. It collects the retrieval history that later
relevance ranking and graph upkeep (gap and prune analysis) need,
since that history cannot be backfilled.

## MCP

remem is an MCP server. `POST /mcp` speaks JSON-RPC over the
streamable HTTP transport, stateless and without SSE. The same
bearer auth applies when `API_KEY` is set. Cursor configuration:

```json
{
  "mcpServers": {
    "remem": {
      "url": "http://localhost:8080/mcp",
      "headers": { "Authorization": "Bearer <key>" }
    }
  }
}
```

Tools: `search_memory`, `get_entity`, `list_entities`,
`create_entity`, `rename_entity`, `merge_entities`, `delete_entity`,
`add_observations`, `remove_observations`, `create_relation`,
`delete_relation`.

There is no read-the-whole-graph tool on purpose. Search is the way
in, so agents retrieve memories by relevance instead of loading the
full graph each session. `list_entities` returns names and counts
only, for spotting entities that need a split or a merge. Tool
descriptions steer agents to search before writing and to keep the
graph curated.

## Development

```
koja check    # type check
koja test     # unit tests, plus integration tests against compose
koja format   # format in place
```

The integration tests in `test/store_test.koja` and
`test/mcp_test.koja` expect the compose PostgreSQL on port 5435.

## License

Copyright (c) 2026 Henry Popp

This project is MIT licensed.
