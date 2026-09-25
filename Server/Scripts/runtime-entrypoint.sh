#!/bin/sh
set -eu
umask 077

fail() {
    printf '%s\n' "mp2_runtime_preparation_failed: $1" >&2
    exit 1
}

case "$(id -u)" in
    0)
        # Railway mounts its volume as root. Root is allowed only for this
        # explicit, fixed-path initialization, never for the service process.
        [ "${RAILWAY_RUN_UID-}" = "0" ] || fail "root requires explicit Railway initialization"
        [ "${MP2_OUTBOX_DIRECTORY-/app/data/outbox}" = "/app/data/outbox" ] \
            || fail "root initialization requires the fixed outbox path"
        for directory in /app /app/data /app/data/outbox /app/data/outbox/delivered; do
            [ ! -L "$directory" ] || fail "symlink directory rejected"
            if [ -e "$directory" ]; then
                [ -d "$directory" ] || fail "non-directory path rejected"
            fi
        done
        [ -d /app/data ] || fail "data mount directory is missing"
        # Do not recursively chown the volume or alter existing result files.
        install -d -m 0700 -o 10001 -g 10001 /app/data/outbox /app/data/outbox/delivered
        exec /usr/bin/setpriv --reuid=10001 --regid=10001 --clear-groups --no-new-privs \
            /app/PimPoPomRealtime "$@"
        ;;
    10001)
        [ "$(id -g)" = "10001" ] || fail "unexpected runtime group"
        exec /app/PimPoPomRealtime "$@"
        ;;
    *) fail "unexpected runtime user" ;;
esac
