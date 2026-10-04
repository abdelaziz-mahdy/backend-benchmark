# Use the official Rust image for both building and running the application
FROM rust:latest

# Install SSL certificates and any other dependencies your application might need
RUN apt-get update && apt-get install -y libssl-dev ca-certificates && rm -rf /var/lib/apt/lists/*

# Create a new application directory
WORKDIR /usr/src/app

# Copy your source code and Cargo files into the image
COPY ./Cargo.toml ./Cargo.toml
# Uncomment the next line if you have a Cargo.lock file
# COPY ./Cargo.lock ./Cargo.lock
COPY ./src ./src

# Build your application for release
RUN cargo build --release

# Expose port 8000 to the outside world
EXPOSE 8000

# copy extra files to the target
COPY ./migration.sql ./migration.sql
# Run the built executable
CMD ["./target/release/actix-web-app"]
