#!/usr/bin/env bash
set -euo pipefail
# Run from the repository root. Send only these allowlisted sources to Docker.
COPYFILE_DISABLE=1 tar -c --no-xattrs \
  Server/Dockerfile Server/Package.swift Server/Package.resolved \
  Server/Sources Server/Tests \
  Packages/PimPoPomCore/Package.swift Packages/PimPoPomCore/Sources Packages/PimPoPomCore/Tests \
  | docker build --target verify -f Server/Dockerfile -t pimpopom-mp2-linux-verify:local -
