FROM dart:3.8.1 AS build
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN dart pub get
COPY . .
RUN dart compile exe bin/main.dart -o bin/server

FROM scratch
WORKDIR /app
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server server
COPY --from=build /app/config/ config/
COPY --from=build /app/web/ web/
COPY --from=build /app/migrations/ migrations/
EXPOSE 8000
CMD ["/app/server", "--mode=production", "--server-id=default", "--logging=normal", "--role=monolith", "--apply-migrations"]
