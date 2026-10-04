# FOAM3 notes benchmark. Follows the Dockerfile that foam3's setup/Project tool
# generates: build the binary + resources JARs with FOAM's build (pom.js),
# install them with FOAM's install-docker.sh and start with run-docker.sh.

# Stage 1: fetch foam3 at a pinned commit and build the app.
FROM eclipse-temurin:25 AS builder

RUN apt-get update \
 && apt-get install -y --no-install-recommends git nodejs npm maven ca-certificates \
 && rm -rf /var/lib/apt/lists/*

ARG FOAM3_REPO=https://github.com/foam-foundation/foam3.git
ARG FOAM3_SHA=a0e878e2c74f53016bd990ed04d2b2aaa965aa26

WORKDIR /app
RUN git init -q foam3 \
 && git -C foam3 remote add origin "${FOAM3_REPO}" \
 && git -C foam3 fetch -q --depth 1 origin "${FOAM3_SHA}" \
 && git -C foam3 checkout -q FETCH_HEAD \
 && cd foam3 && npm install --no-audit --no-fund

COPY pom.js ./
COPY src ./src
COPY journals ./journals
COPY deployment ./deployment

# -Jbench adds deployment/bench (the HTTP server on port 8000).
RUN node foam3/tools/build.js -Jbench --build-docker-tar \
 && node foam3/tools/build.js -Jbench --build-resources-tar

# Stage 2: runtime. JDK rather than JRE, as in FOAM's template (scripts may
# need jdk.compiler).
FROM eclipse-temurin:25

RUN apt-get update \
 && apt-get install -y --no-install-recommends unzip \
 && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/build/package/ /tmp/package/
RUN mkdir -p /tmp/extract \
 && for t in /tmp/package/*.tar.gz; do tar -xzf "$t" -C /tmp/extract; done \
 && /tmp/extract/bin/install-docker.sh -A /opt/bench -E /tmp/extract -N bench -V 1.0.0 \
 && mkdir -p /opt/bench/journals /opt/bench/documents /opt/bench/logs \
 && rm -rf /tmp/extract /tmp/package

# No VOLUME: runtime journals (the embedded variant's "notes" journal) live in
# the container layer, so every container starts with an empty store.
# Heap: install-docker.sh's conf/shrc.custom sizes it to 75% of the container
# memory; etc/shrc.local adds FOAM's production JVM flags (ZGC etc.).
EXPOSE 8000
WORKDIR /opt/bench
CMD ["bin/run-docker.sh", "-A", "/opt/bench", "-N", "bench", "-V", "1.0.0", "-W", "8000"]
