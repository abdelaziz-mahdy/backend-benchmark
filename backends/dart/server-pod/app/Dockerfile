FROM dart:3.14.0 AS build
# An older Serverpod release to build for the version history (see `history`
# in backend.yaml); empty builds the version pinned in pubspec.lock.
ARG FRAMEWORK_VERSION=
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN if [ -n "$FRAMEWORK_VERSION" ]; then \
      sed -i "s/^  serverpod: .*/  serverpod: $FRAMEWORK_VERSION/" pubspec.yaml && \
      rm pubspec.lock; \
    fi && \
    dart pub get
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
