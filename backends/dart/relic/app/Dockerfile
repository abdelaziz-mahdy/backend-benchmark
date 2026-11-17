FROM dart:3.14.0 AS build
# An older Relic release to build for the version history (see `history` in
# backend.yaml); empty builds the version pinned in pubspec.lock. Relic 1.x
# has no native adapter, so its build drops relic_native and serves through
# relic_io only.
ARG FRAMEWORK_VERSION=
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
COPY lib/ lib/
RUN if [ -n "$FRAMEWORK_VERSION" ]; then \
      sed -i -e "s/^  relic: .*/  relic: $FRAMEWORK_VERSION/" pubspec.yaml && \
      case "$FRAMEWORK_VERSION" in 1.*) \
        sed -i '/^  relic_native:/d' pubspec.yaml && \
        mv lib/serve_v1.dart lib/serve.dart ;; \
      esac && \
      rm pubspec.lock; \
    fi && \
    dart pub get
COPY bin/ bin/
COPY migration.sql ./
# dart build (not compile exe): relic_native ships its native library through
# a build hook, which only `dart build` bundles.
RUN dart build cli --target bin/main.dart -o build/server

FROM scratch
WORKDIR /app
COPY --from=build /runtime/ /
COPY --from=build /app/build/server/bundle/ ./
COPY --from=build /app/migration.sql ./
EXPOSE 8000
CMD ["/app/bin/main"]
