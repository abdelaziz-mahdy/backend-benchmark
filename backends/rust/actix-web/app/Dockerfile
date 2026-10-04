FROM rust:1.99 AS build
WORKDIR /usr/src/app
COPY Cargo.toml Cargo.lock ./
COPY src ./src
COPY migration.sql ./
RUN cargo build --release --locked

FROM debian:trixie-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=build /usr/src/app/target/release/actix-web-app /usr/local/bin/app
EXPOSE 8000
CMD ["app"]
