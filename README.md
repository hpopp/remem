# remem

[![CI](https://github.com/hpopp/remem/actions/workflows/ci.yml/badge.svg)](https://github.com/hpopp/remem/actions/workflows/ci.yml)
[![GitHub Release](https://img.shields.io/github/v/release/hpopp/remem)](https://github.com/hpopp/remem/releases)

A memory graph API in Koja. remem stores named entities, timestamped
observations about them, and typed relations between them, backed by
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

| Variable             | Default                 | Purpose                       |
| -------------------- | ----------------------- | ----------------------------- |
| `PORT`               | `8080`                  | HTTP listen port              |
| `DB_HOST`            | `127.0.0.1`             | PostgreSQL host               |
| `DB_PORT`            | `5435`                  | PostgreSQL port               |
| `DB_USER`            | `postgres`              | PostgreSQL user               |
| `DB_PASSWORD`        | none                    | PostgreSQL password           |
| `DB_NAME`            | `remem`                 | Database name                 |
| `DB_STATEMENT_CACHE` | `256`                   | Driver statement cache size   |
| `EMBEDDING_URL`      | `http://127.0.0.1:8081` | TEI embedding server          |
| `API_KEY`            | none                    | When set, require bearer auth |

When `API_KEY` is set, every route except `GET /health` requires an
`Authorization: Bearer <key>` header.

## API

| Route                                 | Purpose                                   |
| ------------------------------------- | ----------------------------------------- |
| `GET /health`                         | Liveness plus a database probe            |
| `GET /graph`                          | Every entity and relation                 |
| `GET /entities?limit=&offset=`        | List entities                             |
| `POST /entities`                      | Create from `{name, type, observations?}` |
| `GET /entities/:name`                 | One entity with its relations             |
| `DELETE /entities/:name`              | Delete an entity, relations cascade       |
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

### Search

`GET /search` embeds the query, ranks by cosine distance against
entity embeddings, ranks entity names by trigram similarity, and
merges both lists with Reciprocal Rank Fusion. When the embedding
server is down, search degrades to fuzzy name ranking alone.

Entity embeddings cover the name, type, and observations. remem
recomputes them after every create and observation change. When the
embedding server is unreachable, the write still succeeds and the
entity joins semantic results after its next successful update.

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

Tools: `search_memory`, `get_entity`, `create_entity`,
`delete_entity`, `add_observations`, `remove_observations`,
`create_relation`, `delete_relation`.

There is no read-the-whole-graph tool on purpose. Search is the only
way in, so agents retrieve memories by relevance instead of loading
the full graph each session. Tool descriptions steer agents to
search before writing and to keep the graph curated.

## Development

```
koja check    # type check
koja test     # unit tests, plus integration tests against compose
koja format   # format in place
```

The integration tests in `test/store_test.koja` expect the compose
PostgreSQL on port 5435.

## License

Copyright (c) 2026 Henry Popp

This project is MIT licensed.
