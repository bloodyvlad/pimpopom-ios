# Open decisions

These questions are intentionally unresolved. Recommended defaults guide discussion but are not accepted until recorded in `docs/DECISIONS.md`.

## P0 — Resolve before Xcode/service configuration

| Decision | Recommended starting point | Why it matters |
| --- | --- | --- |
| Seller/team identity | OTC Software organization, if that is the legal enrolled entity | Storefront name, contracts, signing, tax, key ownership |
| PimPoPom clearance | Search trademarks, App Store names, domains, and social handles in launch markets | Avoid expensive rebrand after art/IAP creation |
| Minimum OS/devices | Provisional iOS 17+, iPhone portrait; decide iPad separately | API choices, test matrix, market reach, layout |
| Backend ownership | Shared cross-platform backend with a versioned native bearer API | One profile/economy while avoiding copied server code |
| Account model | Sign in with Apple + Google, explicit linking, separate nickname | App Review, existing players, duplicate-account safety |
| Launch regions/languages | US and Canada accepted initially; decide support copy beyond English before release | Consent, localization, tax, support, age rules |
| Children/teen audience | Do not claim Kids Category without a dedicated compliant design | Ads, consent, SDK/data limits, creative and review rules |

## P0 — Resolve before StoreKit or live ads

| Decision | Recommended starting point | Why it matters |
| --- | --- | --- |
| Sandbox/Production backend routing | Separate staging runtime, or an explicitly reviewed dual-environment verifier | TestFlight emits Sandbox transactions while App Store customers use Production |
| Deleted-account purchase recovery | Do not silently attach retained paid evidence to a new profile under P-031 | Apple ownership may outlive a deliberately deleted PimPoPom profile |
| Ad vendor | AdMob + UMP is the initial technical recommendation | SDK/privacy/policy/test integration |
| Active gameplay ads | Reserve requested host, but fill only outside active runs initially | Ad guidance discourages banners beside continuous interaction |
| Compact ad-host policy | Define the minimum playable board size; suppress/collapse only between runs below it | Prevent a banner from shrinking or moving reaction targets |
| Tracking/ATT | Contextual/nontracking first; no ATT unless truly needed | Privacy, conversion, review, consent complexity |
| Ad age/content settings | Derived from accepted audience/region policy | Legal and platform compliance |

## P0 — Resolve before external TestFlight

| Decision | Recommended starting point | Why it matters |
| --- | --- | --- |
| Account deletion/retention | In-app initiation, provider revocation, anonymize where possible, retain only justified immutable audit | App Review and data rights |
| Public nickname safety | Filter plus report/block/moderation/appeal policy | Public user-generated identity content |
| Security/support contacts | Dedicated private security and public support channels | Incident response and review metadata |
| Privacy/Terms URLs | Seller-owned HTTPS pages with versioned content | Store metadata and user rights |
| Pancake asset | Obtain independent redistribution proof or replace | Current baseline flags unresolved rights |
| Logo/sting rights | Original production, source/master/hash records, performer release if applicable | Brand and audio distribution rights |

## P1 — Scope decisions

| Decision | Recommended starting point | Impact |
| --- | --- | --- |
| Historical Zen board | Keep read-only if cross-platform context matters; never accept native Zen writes | Navigation and API scope |
| Native admin UI | Exclude from customer MVP; retain secured web administration | Reduces privileged app attack/review surface |
| Haptics | Optional independent toggle, Core Haptics with fallback | Feel, accessibility, device variance |
| Audio session | `.ambient`-style behavior respecting Silent switch; validate product intent | Player expectations and other audio mixing |
| iPad/landscape | Add only with designed layouts and device QA | Significant layout/input test scope |
| Analytics/crash vendor | Start with minimum Apple diagnostics or a privacy-reviewed vendor | Data disclosure, SDK and consent surface |
| Offline scope | Local Zen/Arcade practice only; no delayed ranked promotion or purchase credit | Integrity and UX |
| Cross-platform paid coins | Show one server balance only after App Review/payment policy review | Store rules and reconciliation |

## Decision process

For each item, record owner, alternatives, evidence, selected option, date, rollout implications, and a new decision-log entry. Secrets, private account identifiers, private keys, and operational credentials do not belong in this public Markdown file; public StoreKit product identifiers and accepted price points may be recorded.
