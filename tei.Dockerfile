FROM rust:1-bookworm AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    git cmake pkg-config libssl-dev && \
    rm -rf /var/lib/apt/lists/*

ARG TEI_VERSION=1.9.3
RUN git clone --depth 1 --branch v${TEI_VERSION} \
    https://github.com/huggingface/text-embeddings-inference.git /tei

WORKDIR /tei
RUN cargo build --release -p text-embeddings-router

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates libssl3 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /tei/target/release/text-embeddings-router /usr/local/bin/

ENTRYPOINT ["text-embeddings-router"]
