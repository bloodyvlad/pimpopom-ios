#!/bin/sh
set -eu
# Only invoked in a disposable Linux verify container, never on the host/runtime.
[ "${MP2_ENTRYPOINT_TEST_CONTAINER-}" = "1" ]
[ "$(id -u)" = "0" ]
[ ! -e /app ] && [ ! -L /app ]
entrypoint=$(realpath "$1")
fixture=$(realpath "$2")
groupadd --gid 10001 realtime
useradd --uid 10001 --gid 10001 realtime
install -d -m 0755 /app/data /app/outside
install -m 0555 "$fixture" /app/PimPoPomRealtime

expect_failure() {
    if "$@"; then
        printf '%s\n' "runtime entrypoint unexpectedly succeeded" >&2
        exit 1
    fi
}

expect_failure env -u RAILWAY_RUN_UID sh "$entrypoint"
expect_failure env RAILWAY_RUN_UID=00 sh "$entrypoint"
expect_failure env RAILWAY_RUN_UID=0 MP2_OUTBOX_DIRECTORY=/app/outside sh "$entrypoint"
printf '%s' 'preserved outside evidence' > /app/outside/evidence.json
outside_state=$(stat -c '%u:%g:%a' /app/outside/evidence.json)
outside_directory_state=$(stat -c '%u:%g:%a' /app/outside)
rmdir /app/data
ln -s /app/outside /app/data
expect_failure env RAILWAY_RUN_UID=0 sh "$entrypoint"
rm /app/data
mkdir /app/data
printf '%s' 'preserved outbox-path file' > /app/data/outbox
expect_failure env RAILWAY_RUN_UID=0 sh "$entrypoint"
[ "$(cat /app/data/outbox)" = 'preserved outbox-path file' ]
rm /app/data/outbox
ln -s /app/outside /app/data/outbox
expect_failure env RAILWAY_RUN_UID=0 sh "$entrypoint"
rm /app/data/outbox
ln -s /app/missing /app/data/outbox
expect_failure env RAILWAY_RUN_UID=0 sh "$entrypoint"
rm /app/data/outbox
mkdir /app/data/outbox
ln -s /app/outside /app/data/outbox/delivered
expect_failure env RAILWAY_RUN_UID=0 sh "$entrypoint"
rm /app/data/outbox/delivered
printf '%s' 'preserved file at directory path' > /app/data/outbox/delivered
expect_failure env RAILWAY_RUN_UID=0 sh "$entrypoint"
[ "$(cat /app/data/outbox/delivered)" = 'preserved file at directory path' ]
rm /app/data/outbox/delivered
printf '%s' 'preserved pending evidence' > /app/data/outbox/evidence.json
pending_state=$(stat -c '%u:%g:%a' /app/data/outbox/evidence.json)
env RAILWAY_RUN_UID=0 MP2_EXPECT_NNP=1 sh "$entrypoint"
[ "$(stat -c '%u:%g:%a' /app/data/outbox)" = '10001:10001:700' ]
[ "$(stat -c '%u:%g:%a' /app/data/outbox/delivered)" = '10001:10001:700' ]
[ "$(stat -c '%u:%g:%a' /app/data/outbox/evidence.json)" = "$pending_state" ]
[ "$(cat /app/data/outbox/evidence.json)" = 'preserved pending evidence' ]
[ "$(stat -c '%u:%g:%a' /app/outside/evidence.json)" = "$outside_state" ]
[ "$(stat -c '%u:%g:%a' /app/outside)" = "$outside_directory_state" ]
[ "$(cat /app/outside/evidence.json)" = 'preserved outside evidence' ]
setpriv --reuid=10001 --regid=10001 --clear-groups env -u RAILWAY_RUN_UID sh "$entrypoint"
expect_failure setpriv --reuid=10002 --regid=10002 --clear-groups sh "$entrypoint"
expect_failure setpriv --reuid=10001 --regid=10002 --clear-groups sh "$entrypoint"
# An unprivileged invocation cannot use the Railway flag to fix permissions.
chmod 0500 /app/data/outbox
expect_failure setpriv --reuid=10001 --regid=10001 --clear-groups env RAILWAY_RUN_UID=0 sh "$entrypoint"
chmod 0700 /app/data/outbox
[ "$(find /app/data/outbox -name '.entrypoint-check.*' | wc -l)" -eq 0 ]
printf '%s\n' 'Runtime entrypoint checks passed.'
