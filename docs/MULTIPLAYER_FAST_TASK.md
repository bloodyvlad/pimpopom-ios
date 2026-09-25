# Historical FAST Multiplayer pointer

Superseded for new client development by the owner-approved
[Multiplayer v2 replacement](MULTIPLAYER_V2_REBUILD.md).

FAST described the old GameKit/v1 peer coordinator, sealed frontiers,
acknowledgement recovery and unanimous transcript settlement. Those rules are not
the local v2 contract. The integration candidate removes that live client layer;
historical v1 results and unrelated Game Center integration remain.

Build 24 was uploaded on 2026-08-22 and found VALID by the 2026-09-08 direct App
Store Connect check. That historical binary is not today's v2 source. See
[CURRENT_VERSION](CURRENT_VERSION.md) for groups, external-beta caveats and open gates.

The full superseded plan and its test history remain recoverable from Git
history, including the v1 audit baseline
`df16cb8ef43adf3752023d12329384c2e0a08eaa`. Do not use old line references,
test counts or build numbers as evidence that v2 is shipped or accepted.
