#!/bin/sh
set -eu

RUNTIME=${PIMPOPOM_SIM_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-26-5}

create_if_missing() {
  name=$1
  device_type=$2

  if xcrun simctl list devices | rg -Fq "$name ("; then
    printf '%s already exists\n' "$name"
  else
    xcrun simctl create "$name" "$device_type" "$RUNTIME"
  fi
}

create_if_missing \
  "PimPoPom iPhone 17" \
  "com.apple.CoreSimulator.SimDeviceType.iPhone-17"
