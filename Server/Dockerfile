# Build context is the PimPoPom repository root, not Server/.
FROM swift:6.3.3-noble AS sources
WORKDIR /workspace
COPY Packages/PimPoPomCore/Package.swift Packages/PimPoPomCore/Package.swift
COPY Packages/PimPoPomCore/Sources Packages/PimPoPomCore/Sources
COPY Packages/PimPoPomCore/Tests Packages/PimPoPomCore/Tests
COPY Server/Package.swift Server/Package.resolved Server/
COPY Server/Sources Server/Sources
COPY Server/Tests Server/Tests
COPY Server/Scripts/runtime-entrypoint.sh Server/Scripts/runtime-entrypoint.sh
WORKDIR /workspace/Server

FROM sources AS verify
RUN MP2_ENTRYPOINT_TEST_CONTAINER=1 sh Tests/runtime-entrypoint-check.sh Scripts/runtime-entrypoint.sh Tests/Fixtures/runtime-identity-probe.sh
RUN swift test -j 4 --disable-automatic-resolution
RUN MP2_ENTRYPOINT_TEST_CONTAINER=1 sh Tests/runtime-readiness-check.sh .build/debug/PimPoPomRealtime
RUN swift test --package-path ../Packages/PimPoPomCore -j 4

FROM sources AS build
RUN swift build -c release -j 4 --disable-automatic-resolution

FROM swift:6.3.3-noble AS runtime
WORKDIR /app
RUN groupadd --gid 10001 realtime && useradd --create-home --uid 10001 --gid 10001 realtime \
    && command -v setpriv \
    && install -d -m 0700 -o 10001 -g 10001 /app/data/outbox /app/data/outbox/delivered
COPY --from=build /workspace/Server/.build/release/PimPoPomRealtime /app/PimPoPomRealtime
COPY Server/Scripts/runtime-entrypoint.sh /app/runtime-entrypoint.sh
RUN chmod 0555 /app/runtime-entrypoint.sh
USER realtime
ENV MP2_BIND=0.0.0.0 MP2_PORT=8080 MP2_OUTBOX_DIRECTORY=/app/data/outbox
EXPOSE 8080
# Persistent storage is mounted by the deployment provider at /app/data.
# Railway rejects Dockerfile VOLUME declarations; local runs pass --mount.
ENTRYPOINT ["/app/runtime-entrypoint.sh"]
