# The load generator: vegeta, a Go HTTP load tool with an open (constant
# arrival rate) model, plus `summary`, which turns its result stream into one
# JSON per step. Measured on 4 cores against Rust actix no_db: clean to 80,000
# requests/s with p99 2.7 ms, where k6 topped out near 48,000.
FROM golang:1.24-alpine AS build
WORKDIR /src
RUN CGO_ENABLED=0 go install github.com/tsenart/vegeta/v12@v12.12.0
COPY summary/ ./
RUN CGO_ENABLED=0 go test ./... && CGO_ENABLED=0 go build -o /go/bin/summary .

FROM alpine:3.22
COPY --from=build /go/bin/vegeta /go/bin/summary /usr/local/bin/
ENTRYPOINT ["sh", "-c"]
