#!/bin/sh
set -eu
[ "$(id -u)" = "10001" ]
[ "$(id -g)" = "10001" ]
[ "$(id -G)" = "10001" ]
if [ "${MP2_EXPECT_NNP-}" = "1" ]; then
    [ "$(awk '/^NoNewPrivs:/ { print $2 }' /proc/self/status)" = "1" ]
fi
[ ! -w /app ]
[ ! -w /app/PimPoPomRealtime ]
probe=$(mktemp /app/data/outbox/.entrypoint-check.XXXXXX)
trap 'rm -f -- "$probe"' EXIT
mv "$probe" /app/data/outbox/delivered/
probe="/app/data/outbox/delivered/$(basename "$probe")"
test -f "$probe"
