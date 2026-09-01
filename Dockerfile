FROM kojalang/koja:0.18 AS build

WORKDIR /app

COPY koja.toml koja.lock ./
COPY lib lib

RUN koja deps get

COPY src src

RUN koja build --release

# Release

FROM debian:trixie-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /app/build/release/remem /usr/local/bin/remem

EXPOSE 8080

CMD ["remem"]
