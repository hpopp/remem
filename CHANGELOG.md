# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-09-02

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

[0.2.0]: https://github.com/hpopp/remem/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/hpopp/remem/releases/tag/v0.1.0
