# Multiplayer v2 hosting shortlist

Official-source research checked 2026-09-09. **Decision pending; no account,
purchase, host, deployment or live migration was created by this task.** Prices
are USD before tax and additional usage, not quotes or measured service quality.

Scope: one persistent Swift/Vapor 4 Docker service, WebSockets over TLS/443, and
a private persistent terminal-result outbox. Existing PHP/MySQL stays separate.
The committed runtime needs an unprivileged writable `/app/data` mount. Active
rooms remain in memory: disk persistence does not recover an interrupted match.

## Recommendation

For the owner's proposed **Europe + North America, low-usage setup**, Railway
Hobby is a promising lower-cost option **conditional on measured RAM/CPU and the
regional routing work below**. Its $5 subscription includes $5 of aggregate
usage; it is not $5 per region plus resources. Do not enable raw multi-region
replicas for the current in-memory room service.
[Railway billing](https://docs.railway.com/pricing/plans),
[multi-region constraints](https://docs.railway.com/guides/multi-region-api-failover).

For a simpler **single-region, predictable-cost** alpha, Render Frankfurt remains
an alternative: **$7.25/month** for the $7
512 MB/0.5 CPU service plus 1 GB disk on a $0 Hobby workspace, **if release-image
RSS and load tests fit**. The next size is 2 GB/1 CPU at $25.25 with that disk.
Managed TLS, Docker deployment and predictable compute pricing reduce operational
work. This is a project-fit recommendation, not an uptime/SLA or capacity claim.
[Current Render pricing](https://render.com/pricing),
[Frankfurt region](https://render.com/docs/regions).

For a no-purchase experiment, prefer a **verified Railway trial**: $5 credit for
up to 30 days. It is not a permanently free always-on service. Account/network
verification and retained-volume limits must be checked before relying on it.
[Railway trial](https://docs.railway.com/pricing/free-trial).

## Paid comparison

| Provider | Always-on starting cost | Europe and fit |
| --- | --- | --- |
| Render | $7/month, 512 MB/0.5 CPU; disk $0.25/GB/month. $0 Hobby workspace includes 5 GB bandwidth, then $0.15/GB. | Frankfurt. Managed Docker/TLS/logs; no fixed WebSocket duration limit. Low operational effort. [Pricing](https://render.com/pricing), [regions](https://render.com/docs/regions), [WebSockets](https://render.com/docs/websocket). |
| Railway | $5/month minimum includes $5 usage. Metered RAM $10/GB-month, CPU $20/vCPU-month, disk $0.15/GB-month, egress $0.05/GB. Example average 0.5 GB RAM + 0.1 CPU + 1 GB used disk ≈ $7.15/month, not a fixed quote. | Amsterdam. Managed Docker/TLS; WebSockets exempt from HTTP duration/idle limits. Leave optional Serverless sleep disabled. Low effort, usage-based cost monitoring needed. [Pricing](https://docs.railway.com/pricing/plans), [regions](https://docs.railway.com/deployments/regions), [network limits](https://docs.railway.com/networking/public-networking/specs-and-limits), [sleep](https://docs.railway.com/deployments/serverless). |
| Fly.io | Frankfurt shared-CPU 1×: 512 MB $3.69/month or 1 GB $6.57/month; add $0.15 for 1 GB volume: $3.84 or $6.72. EU internet egress $0.02/GB; snapshot usage can add cost. | Amsterdam, Frankfurt, Paris, London, Stockholm. Docker Machines with managed ingress; moderate CLI/config effort. Exactly one Machine, autostop off. Region-specific prices, not a global flat rate. [Frankfurt pricing matrix](https://fly.io/docs/about/pricing/), [regions](https://fly.io/docs/reference/regions/), [autostop](https://fly.io/docs/launch/autostop-autostart/). |
| DigitalOcean Droplet | $4/month: 512 MiB/1 CPU/10 GiB SSD. More practical start: $6 for 1 GiB/1 CPU/25 GiB SSD/1,000 GiB transfer; $12 for 2 GiB RAM. Backups extra. | Amsterdam, London, Frankfurt. Persistent VM; highest operational effort: OS updates, Docker, TLS reverse proxy, firewall, backups and monitoring. Use a host bind mount outside the container layer. [Pricing](https://www.digitalocean.com/pricing/droplets), [regions](https://docs.digitalocean.com/platform/regional-availability/). |

512 MB is a price floor, not a verified sizing recommendation. Build the release
image separately; do not expect a small runtime instance to compile Swift. Measure
room count, RSS, CPU/tick backlog, outbox growth and egress before selecting a size.
No live latency, account eligibility, regional capacity or provider SLA was tested.

## Proposed EU + North America layout — not implemented

Railway offers Amsterdam and Virginia (US East). Its native multi-region service
routes users to a nearby region and requests randomly among that region's replicas;
**sticky sessions are not supported and replicas cannot use volumes**. That is a
stateless-API model, not automatic distributed match authority. Enabling it as-is
could send players/reconnects to different isolated room memories.
[Official multi-region guide](https://docs.railway.com/guides/multi-region-api-failover).

A direct future design is **two separate, single-replica regional services**, each
with its own persistent disk and explicit regional WSS endpoint. Every room has
one selected home region; all participants and reconnects route to that same
authority, even when a participant lives on the other continent. There is no
global tap/state synchronization between regions.

Required application work: a shared room directory recording the room's regional
endpoint, explicit region selection/discovery, ticket-to-endpoint admission policy,
and reconnect routing that preserves the room's region. PHP can own authentication
and a low-frequency central directory outside the live input path; this directory
is a **new proposal**, not present in the current single-endpoint bridge. Do not
introduce two competing live Ready/Start authorities. Regional failover of an
in-progress room remains unsupported unless durable room recovery is designed.

### Illustrative always-on monthly costs

Both Railway regions below assume average CPU usage **0.02 vCPU each**, **1 GB
used disk each**, and Serverless sleep disabled. RAM is average billed usage in
decimal GB, not a measured release RSS or a provisioned capacity guarantee.

| RAM per region | Two-region Railway arithmetic | Estimated resources/month |
| --- | --- | ---: |
| 0.25 GB | `2 × (0.25 × $10 + 0.02 × $20 + 1 × $0.15)` | $6.10 |
| 0.50 GB | `2 × (0.50 × $10 + 0.02 × $20 + 1 × $0.15)` | $11.10 |
| 1.00 GB | `2 × (1.00 × $10 + 0.02 × $20 + 1 × $0.15)` | $21.10 |

The Hobby invoice is at least $5, with included credit applied—not an additional
$5 on these totals. In comparison, two Render 512 MB/0.5 CPU instances plus two
1 GB disks are **$14.50/month** on a $0 Hobby workspace, **only if 512 MB fits**.
Thus Railway can be cheaper at low actual usage, but always-on RAM still costs
money and a larger real footprint can reverse the comparison. These examples
exclude bandwidth, tax, builds/add-ons and account-specific pricing. They are not
benchmarks, forecasts or deployment approval.
[Railway rates](https://docs.railway.com/pricing/plans),
[Render rates](https://render.com/pricing).

Fly is also competitive for two always-on regional authorities. The specific
Frankfurt (`fra`) and Ashburn (`iad`) shared-CPU 1× matrices give:

| Allocated RAM per Machine | Frankfurt | US East | Both, including 1 GB volume each |
| --- | ---: | ---: | ---: |
| 512 MB | $3.69 | $3.19 | $7.18/month |
| 1 GB | $6.57 | $5.70 | $12.57/month |

These are published approximately 30-day estimates, excluding traffic, tax,
build resources and optional extras. New organizations use pay-as-you-go with
no required platform subscription. Shared IPv4/IPv6 suffice for WSS on 443;
dedicated IPv4 is optional, not included or needed here. Unlike Railway's actual
resource usage, a running Fly Machine bills its allocated size. The same
room-home routing and measured-capacity requirements apply.
[Regional prices](https://fly.io/docs/about/pricing/),
[billing](https://fly.io/docs/about/billing/),
[public ingress](https://fly.io/docs/networking/services/).

## Transport alternatives under discussion — not a new decision

The removed v1 client used GameKit `GKMatch` plus custom FAST input seals,
acknowledgements and peer-consistency checks. V2 uses Foundation
`URLSessionWebSocketTask` with the dedicated Vapor service. Game Center identity
and historical publication remain separate. The app does not directly use
Network framework APIs for v2, though Apple's URLSession is built on its
networking stack. A hosting-provider change does not require replacing gameplay.
[WebSocket API](https://developer.apple.com/documentation/foundation/urlsessionwebsockettask),
[Network framework](https://developer.apple.com/documentation/network).

GameKit peer-to-peer remains an alternative for online or nearby play without
our live server. For a single authority, one phone would run the room engine;
host departure/backgrounding, rejoin and host migration need explicit design.
Nearby matchmaking is supported, but this is not a guarantee of offline-only
operation or a developer-controlled LAN route.
[Nearby discovery](https://developer.apple.com/documentation/gamekit/gkmatchmaker),
[host selection](https://developer.apple.com/documentation/gamekit/gkmatch/choosebesthostingplayer(completionhandler:)).

A separate explicitly local mode could use Network framework with Bonjour and
opt-in peer-to-peer Wi-Fi; it could reuse the pure engine but needs a new local
transport, trusted host admission and lifecycle tests. Custom QUIC to a dedicated
server is another option, not limited to LAN. QUIC datagrams could avoid ordered
stream blocking for replaceable snapshots, but require a compatible server,
reliable control/input handling and fallback validation. Neither alternative is
implemented. Keep immediate local feedback and bounded timing compensation
regardless of transport; test loss/jitter before expanding scope.
[Apple networking guidance](https://developer.apple.com/documentation/technotes/tn3151-choosing-the-right-networking-api),
[local peer networking](https://developer.apple.com/documentation/technotes/tn3213-moving-from-multipeer-connectivity-to-network-framework).

## Persistence, sockets and scaling

- Render disks are accessible to one service instance, prevent horizontal scaling,
  and disable zero-downtime deploys. Deploys/maintenance disconnect sockets; the
  client must reconnect. [Disk limitations](https://render.com/docs/disks).
- Railway volumes also prevent replicas and require downtime during deployment
  or region migration. Its optional Serverless mode sleeps after roughly 5–10
  minutes without outbound traffic; keep that off for this authority/outbox.
  [Volumes](https://docs.railway.com/reference/volumes),
  [Serverless behavior](https://docs.railway.com/deployments/serverless).
- Fly volumes belong to one Machine/host/region and are not automatically
  replicated. Autostop must be off for an always-on authority. No provider can
  make two independent copies of this in-memory room service share a room merely
  by increasing replicas. [Volume architecture](https://fly.io/docs/volumes/overview/).
- One-instance hosting matches the current design but is not high availability.
  Before release: test graceful drain, supervised restart, disk permissions/full
  disk, durable retry, backups/retention, restore and rollback. A process restart
  must show an infrastructure interruption, never fabricated wins.

## Free/trial caveats

| Option | Actual limit | Implication |
| --- | --- | --- |
| Railway trial | $5 credit/up to 30 days, then Free with $1/month credit. Full versus restricted networking depends on automated verification; trial volume retention expires after credit expiry. | Best short experiment if the account can reach PHP. Not indefinitely free production. [Terms](https://docs.railway.com/pricing/free-trial). |
| Render Free | 15-minute idle sleep without inbound HTTP/WebSocket messages; approximately one-minute cold wake; 750 hours/workspace/month; no persistent disk. | Can demonstrate ephemeral sockets, but cannot validate durable outbox survival. [Limits](https://render.com/docs/free). |
| Fly trial | Two total VM-hours or seven days, whichever first; trial Machines automatically stop after five minutes. | Poor fit for complete 15-minute matches. Adding a card starts paid usage. [Limits](https://fly.io/docs/about/free-trial/). |

No free production plan is recommended. DigitalOcean promotional credits were not
relied on: eligibility and active promotion must be verified at the owner's signup.

## Current Vercel correction

Do **not** repeat the old blanket claim that Vercel cannot host WebSockets or
Docker. WebSockets entered public beta on 2026-06-22; OCI/Dockerfile Functions
followed on 2026-06-30. Both are documented now.
[WebSocket announcement](https://vercel.com/changelog/websocket-support-is-now-in-public-beta),
[Docker announcement](https://vercel.com/changelog/bring-your-dockerfile-to-vercel-functions).

The mismatch is lifecycle/state: sockets close at the Function duration limit,
container Functions autoscale and scale down when idle, and durable rooms/outbox
state belongs in an external backing service. A socket stays on one instance,
but other connections need not land on it. Supporting the current authority there
would require a coordination/persistence redesign. Therefore Vercel Functions
are **not recommended for this implementation**, not technically incapable of
WebSockets. Container-specific runtime limits and beta eligibility would need
separate verification if reconsidered.
[WebSocket lifecycle](https://vercel.com/docs/functions/websockets),
[Docker Function state/lifecycle](https://vercel.com/kb/guide/does-vercel-support-docker-deployments).

Cloud Run is possible but less direct: WebSockets have a 60-minute maximum request
timeout (five-minute default), connection affinity is best effort, and cross-instance
state needs coordination. Open sockets keep the instance active/billable. Its
stateless scaling model adds work without a demonstrated alpha advantage.
[Cloud Run WebSocket guidance](https://docs.cloud.google.com/run/docs/triggering/websockets).

## Tomorrow's decision

Choose managed convenience (Render/Railway), a lower-cost Machine with more config
(Fly), or a self-managed VM (DigitalOcean). Only after explicit owner approval:
confirm the actual region/plan/payment terms, create the host, inject private
configuration, verify authenticated WSS/PHP integration and rollback, then prepare
a separately authorized new TestFlight release. Keep secrets out of source and
logs; do not publish ticket values in URLs.
