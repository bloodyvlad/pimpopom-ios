# Railway EU beta deployment

Owner-authorized on 2026-09-09: one EU multiplayer service, the separate PHP v2
bridge, and a new TestFlight build for the existing Internal QA and External QA
groups. The hosted release and boundary checks below passed. Real-player match
acceptance and Apple's external beta approval are separate gates.

## Provisioned target

| Item | Value |
| --- | --- |
| Workspace | bloodyvlad's Projects |
| Project | PimPoPom (`e7516d98-16d5-4db9-822c-480caa0625ba`) |
| Environment | production (`5c9fb522-0a21-48fd-bff9-4046f6ad3ae8`); unranked beta workload |
| Service | multiplayer-eu (`dacfc84e-bebe-429d-9ead-0387427b2cda`) |
| Region | Amsterdam, `europe-west4-drams3a`; Railway currently has no Spain region |
| Authority | Exactly one instance; do not add regional or horizontal replicas |
| Public socket | `wss://multiplayer-eu-production.up.railway.app/multiplayer/v2` |
| Health | `https://multiplayer-eu-production.up.railway.app/health` |
| Volume | `1e2262c1-9f41-4d85-acef-ed8dd245bcc6`, mounted at `/app/data`, initial 500 MB |
| Billing at setup | Trial, $5 credit/30 days; no paid subscription activated by this task |

The native client obtains the socket URL from the authenticated PHP ticket
response. Its HTTP backend remains `https://speedytapper.otcsoft.com`.

## Runtime configuration

The repository-root Docker build uses `Server/Dockerfile`. Upload an allowlisted
`git archive` of a reviewed clean commit, never the entire working checkout.
Include the Server manifests, sources, tests and startup scripts plus the shared
core manifest, sources and tests. Exclude app assets, local configuration, build
outputs, Git metadata and credentials.

Set both `PORT=8080` and `MP2_PORT=8080`, `MP2_BIND=0.0.0.0`, and
`RAILWAY_DOCKERFILE_PATH=Server/Dockerfile`. The domain target port is 8080.
Set `MP2_OUTBOX_DIRECTORY=/app/data/outbox`.

Railway mounts its volume as root. `RAILWAY_RUN_UID=0` is only a startup permission
bridge: the checked-in entrypoint must initialize the exact private outbox
directories and drop to UID/GID 10001 before starting the game service. Verify
the running process identity and an actual write/rename/read/delete probe. A
healthy process without writable durable storage is not deployment acceptance.
Never enable `MP2_DEV_AUTH` on this host.

The following endpoints must be deployed on the separate PHP host:

- `MP2_TICKET_INTROSPECTION_URL=https://speedytapper.otcsoft.com/api/internal/multiplayer/v2/tickets/redeem`
- `MP2_SESSION_VALIDATION_URL=https://speedytapper.otcsoft.com/api/internal/multiplayer/v2/sessions/validate`
- `MP2_RESULTS_URL=https://speedytapper.otcsoft.com/api/internal/multiplayer/v2/results`

`MP2_SERVICE_KEY` is a private service variable. PHP uses the same value as
`SPEEDYTAPPER_MULTIPLAYER_SERVICE_SECRET`, and the public socket URL above as
`SPEEDYTAPPER_REALTIME_URL`. Keep the key out of URLs, source, command arguments,
release records and logs. Pass it through stdin/private configuration only.
PHP migration 023 must be applied before the v2 code serves requests.

## Deployment and operation

- Serverless/sleep is disabled. Healthcheck `/health`, timeout 120 seconds.
- Restart policy: On Failure, ten retries (compatible with the trial).
- One instance, zero deployment overlap, 30-second SIGTERM grace. This grace is
  not implemented live-match migration or guaranteed completion draining.
- The volume survives restarts; live rooms do not. Redeploy only when no match
  is running, or explicitly communicate the infrastructure interruption.
- The result outbox survives and retries acknowledgements. It is unranked and
  cannot award coins, achievements or Game Center scores.
- Railway's deployment healthcheck is not continuous uptime monitoring.
- Trial expiry, account networking restrictions, memory use, CPU cost and
  remaining credit must be checked before sustained QA. No auto-upgrade is assumed.

Railway settings were applied through its official CLI/API rather than adding
the legacy `railway.json` format, which current Railway documentation deprecates.
Inspect the exact service's environment configuration and deployment metadata
before future releases. Do not apply a whole-environment config containing
unreviewed variable or service changes.

## Acceptance and rollback

Record the source SHA, allowlisted archive SHA-256, Railway deployment ID, image
identity, region, actual process UID, health/WSS checks and outbox restart proof.
Verify PHP migration ledger, service authentication, normal session/CSRF gates,
and matching configuration without logging secrets. Reject synthetic development
tickets on the hosted service. Unit and local fixture tests do not prove real
account sign-in, physical latency, or an entire internet match.

Before uploading iOS, run the source gate and inspect the Staging archive. Assign
the processed build to both existing QA groups and submit external Beta App
Review when required. Report assignment and approval separately; do not create
or change a public testing link.

For the first release there is no prior Railway application deployment to roll
back to. Retain its source artifact for exact redeployment. If the rollout fails,
stop new v2 admission through PHP configuration while retaining the volume and
existing Arcade/v1 behavior. A later Railway rollback restores an earlier image,
not in-progress room memory. Retain the separate PHP predeployment source/config/
database backups and do not drop additive v2 tables as routine rollback.

## Evidence

Verified 2026-09-09:

| Evidence | Value |
| --- | --- |
| Clean source | `962a39de80277534dd45eca56ca913217bde1fbb` |
| Railway deployment | `ece352a2-d7e1-4512-9f16-aad11daa6602`, SUCCESS, one Amsterdam replica |
| Source tar SHA-256 | `eceb9ffdf5579f2c20b38b266095c933ed5dd09c98a9db9e9abed1dcc5e213aa` |
| Linux/amd64 image digest | `sha256:02c4d013abeed5e7561d2983a19e848dca5833661ddab039fec40f9fbccc7946` |
| Runtime binary SHA-256 | `da99b0015ff7899a40867baf28bef9c45a9764ecd27283bb4af0dbad4c0a25ec` |
| PHP deployed source | `78b51ee6768d6f049d44b3b8c2d2073e0aac34e0` |
| PHP artifact SHA-256 | `dd5a9ad241d0cd1dce7da9bf1389c130d558bcc4a035a1135e5097f2bccce5c7` |
| PHP migration/season | 023 applied; existing 001–022 already present; season-1 unchanged |

Public TLS health returned protocol 2, `multiplayer-shared-arcade-v2`, ranking
disabled and zero rooms/connections. Negative WSS checks rejected no-hello,
pre-hello Create, development tickets and the wrong protocol. One ping/pong was
52 ms; this isolated sample is not a gameplay-latency benchmark.

Runtime PID 1 was UID/GID 10001 with `NoNewPrivs=1`. Outbox/archive directories
were owner-only 0700 on the `/app/data` ext4 mount. An exact own 43-byte non-JSON
probe survived one controlled empty-service restart with its hash unchanged,
then was removed as UID 10001. No result JSON was created or altered by the test.

Railway-to-PHP HTTPS accepted the real service key and reached the expected
nonexistent-ticket rejection, with CA/hostname verification enabled. The key was
sent through TLS stdin, never arguments/logs. PHP passed 35 live boundary checks,
including service authentication, normal session/CSRF/origin gates, retained API
compatibility and private-path denial. This does not establish successful player
sign-in, a complete hosted match, reconnect/revocation, or real result delivery.

Temporary Railway SSH registration/material and all temporary Hostinger cron jobs
were removed; original workers and SSH configuration were preserved. SSH used
task-local, strict first-use host-key pinning, not an independently published key.
The first attempted Railway deployment failed before building because Dockerfile
`VOLUME` declarations are unsupported; only the successful source above is live.

Retained local artifacts/logs: `build/releases/build25-20260909/`. The separate PHP
release/rollback record is
`/Users/vlad/Documents/SpeedyTapper-release-artifacts/20260909-v2.cwDiG8/RELEASE.md`.
See [iOS release state](../docs/RELEASE.md) for Apple processing/review evidence.

Sources checked 2026-09-09: [regions](https://docs.railway.com/deployments/regions),
[volumes](https://docs.railway.com/volumes),
[healthchecks](https://docs.railway.com/deployments/healthchecks),
[trial](https://docs.railway.com/pricing/free-trial),
[legacy configuration](https://docs.railway.com/config-as-code/reference).
