FROM rust:1.64.0

WORKDIR /app

RUN apt update && apt install lld clang -y

COPY . .

# sqlx tries to connect to postgres at compile time to verify schemas
# if I run `cargo sqlx prepare -- --lib` which saves the schema metadata locally
# this env var tells sqlx to verify from that instead
ENV SQLX_OFFLINE true

RUN cargo build --release

ENTRYPOINT ["./target/release/zero2prod"]