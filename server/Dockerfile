FROM rust:1.83 AS builder

WORKDIR /app

# Build context is the repository root (the signaling server depends on the
# core crate at packages/core, so `server/` alone is not a sufficient context):
#
#   docker build -f server/Dockerfile -t doorstep-server .
#
# The core crate must sit next to `server/` so that the `../packages/core`
# path dependency in server/Cargo.toml resolves identically inside the image.
COPY packages/core /packages/core
COPY server/Cargo.* ./

# Compile dependencies against a dummy main so the layer caches.
RUN mkdir src && echo 'fn main() { panic!("Dummy Image Called!") }' > ./src/main.rs
RUN cargo build --release

# Add source
COPY server/src ./src

# Break cargo cache
RUN touch ./src/main.rs

# Compile
RUN cargo build --release

FROM debian:bookworm AS runtime

COPY --from=builder /app/target/release/server /server

EXPOSE 3000
ENTRYPOINT ["/server"]
