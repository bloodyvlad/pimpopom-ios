# Build context is the PimPoPom repository root, not Server/.
FROM swift:6.3.3-noble AS sources
WORKDIR /workspace
COPY Packages/PimPoPomCore/Package.swift Packages/PimPoPomCore/Package.swift
COPY Packages/PimPoPomCore/Sources Packages/PimPoPomCore/Sources
COPY Packages/PimPoPomCore/Tests Packages/PimPoPomCore/Tests
COPY Server/Package.swift Server/Package.resolved Server/
COPY Server/Sources Server/Sources
COPY Server/Tests Server/Tests
WORKDIR /workspace/Server

FROM sources AS verify
RUN swift test -j 4 --disable-automatic-resolution
RUN swift test --package-path ../Packages/PimPoPomCore -j 4

FROM sources AS build
RUN swift build -c release -j 4 --disable-automatic-resolution

FROM swift:6.3.3-noble AS runtime
WORKDIR /app
RUN useradd --create-home --uid 10001 realtime && mkdir -p /app/data/outbox && chown -R realtime:realtime /app
COPY --from=build /workspace/Server/.build/release/PimPoPomRealtime /app/PimPoPomRealtime
USER realtime
ENV MP2_BIND=0.0.0.0 MP2_PORT=8080 MP2_OUTBOX_DIRECTORY=/app/data/outbox
EXPOSE 8080
VOLUME ["/app/data"]
ENTRYPOINT ["/app/PimPoPomRealtime"]
