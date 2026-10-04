FROM dart:3.13.5 AS build
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN dart pub get
COPY . .
# dart build (not compile exe): serverpod 4 depends on sqlite3, which has native build hooks.
RUN dart build cli --target bin/main.dart -o build/server

FROM scratch
WORKDIR /app
COPY --from=build /runtime/ /
COPY --from=build /app/build/server/bundle/ ./
COPY --from=build /app/config/ config/
COPY --from=build /app/web/ web/
COPY --from=build /app/migrations/ migrations/
EXPOSE 8000
CMD ["/app/bin/main", "--mode=production", "--server-id=default", "--logging=normal", "--role=monolith", "--apply-migrations"]
