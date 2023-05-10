#Builder stage
FROM rust:1.64.0 as chef
RUN apt update && apt install lld clang -y
RUN cargo install cargo-chef
WORKDIR /app
COPY . .

# Compute a lock-like file for our project
RUN cargo chef prepare --recipe-path recipe.json

RUN update-ca-certificates

# Create unpriviliged appuser
ENV USER=app
ENV UID=10001

RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    "${USER}" \

FROM chef as builder
COPY --from=chef /app/recipe.json recipe.json
# Build the dependencies without building the application for docker caching
RUN cargo chef cook --release --recipe-path recipe.json
COPY . .
# sqlx tries to connect to postgres at compile time to verify schemas
# if I run `cargo sqlx prepare -- --lib` which saves the schema metadata locally
# this env var tells sqlx to verify from that instead
ENV SQLX_OFFLINE true
RUN cargo build --release --bin zero2prod

#Runtime stage
FROM debian:bullseye-slim AS runtime
WORKDIR /app
# Install OpenSSL - it is dynamically linked by some of our dependencies
# Install ca-certificates - it is needed to verify TLS certificates
# when establishing HTTPS connections
RUN apt-get update -y \
  && apt-get install -y --no-install-recommends openssl ca-certificates \
  # Clean up
  && apt-get autoremove -y \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group
COPY --from=builder /app/target/release/zero2prod zero2prod
COPY configuration configuration

USER app:app

ENV APP_ENVIRONMENT production
ENTRYPOINT ["./target/release/zero2prod"]