#!/bin/sh
set -eu
ulimit -c 0
# Run only in the disposable verify image, after building the service.
[ "${MP2_ENTRYPOINT_TEST_CONTAINER-}" = "1" ]
[ "$(id -u)" = "0" ]
binary=$(realpath "$1")
test_root=$(mktemp -d /tmp/mp2-runtime-readiness.XXXXXX)
chmod 0755 "$test_root"
install -d -m 0700 -o 10001 -g 10001 "$test_root/outbox" "$test_root/outbox/delivered"
printf '%s' 'pending evidence' > "$test_root/outbox/sentinel.json"
printf '%s' 'delivered evidence' > "$test_root/outbox/delivered/sentinel.json"

for denied in "$test_root/outbox" "$test_root/outbox/delivered"; do
    chmod 0500 "$denied"
    status=0
    timeout 8s setpriv --reuid=10001 --regid=10001 --clear-groups \
        env MP2_DEV_AUTH=1 MP2_BIND=127.0.0.1 MP2_PORT=18081 MP2_OUTBOX_DIRECTORY="$test_root/outbox" \
        "$binary" > "$test_root/rejected-startup.log" 2>&1 || status=$?
    # A missing readiness guard would start the server and hit this timeout.
    [ "$status" -ne 0 ] && [ "$status" -ne 124 ] && [ "$status" -ne 137 ]
    chmod 0700 "$denied"
    [ "$(cat "$test_root/outbox/sentinel.json")" = 'pending evidence' ]
    [ "$(cat "$test_root/outbox/delivered/sentinel.json")" = 'delivered evidence' ]
    [ "$(find "$test_root/outbox" -name '.mp2-readiness-*' | wc -l)" -eq 0 ]
done

# Control: the identical unprivileged binary serves health when storage works.
setpriv --reuid=10001 --regid=10001 --clear-groups \
    env MP2_DEV_AUTH=1 MP2_BIND=127.0.0.1 MP2_PORT=18081 MP2_OUTBOX_DIRECTORY="$test_root/outbox" \
    "$binary" > "$test_root/ready-startup.log" 2>&1 &
service_pid=$!
trap 'kill "$service_pid" 2>/dev/null || true; wait "$service_pid" 2>/dev/null || true' EXIT
attempt=0
until timeout 1 /bin/bash -ec '
    exec 3<>/dev/tcp/127.0.0.1/18081
    printf "GET /health HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n" >&3
    cat <&3
' > "$test_root/health.json" 2>/dev/null; do
    attempt=$((attempt + 1))
    [ "$attempt" -lt 50 ]
    sleep 0.1
done
grep -q '^HTTP/1.1 200' "$test_root/health.json"
grep -q '"protocolVersion":2' "$test_root/health.json"
grep -q '"rankingEnabled":false' "$test_root/health.json"
grep -q '"rankingGameplayRevision":3' "$test_root/health.json"
grep -q '"resultRevision":2' "$test_root/health.json"
[ "$(find "$test_root/outbox" -name '.mp2-readiness-*' | wc -l)" -eq 0 ]
printf '%s\n' 'Unprivileged runtime readiness checks passed.'
