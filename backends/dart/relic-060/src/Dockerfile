FROM dart:3.5.0 AS build
WORKDIR /app
COPY . .
RUN dart pub get
RUN dart compile exe bin/server.dart -o bin/server

FROM alpine:latest
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server server
RUN apk add --no-cache curl
EXPOSE 8000
CMD ["./server"]
