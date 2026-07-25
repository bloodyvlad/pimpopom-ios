#!/usr/bin/env bash

set -euo pipefail

usage() {
    echo "Usage: $0 <simulator-udid> <device-label> <output-root> [app-path]" >&2
    exit 64
}

if [[ $# -lt 3 || $# -gt 4 ]]; then
    usage
fi

device_udid="$1"
device_label="$2"
output_root="$3"
app_path="${4:-/tmp/PimPoPom-screenshot-derived/Build/Products/Debug-iphonesimulator/PimPoPom.app}"
bundle_id="com.otcsoftware.pimpopom"
screenshots_dir="${output_root}/${device_label}"
videos_dir="${output_root}/videos"
rocketsim_cli="${ROCKETSIM_CLI:-}"
recording_pid=""
recording_log=""
recording_path=""

if [[ ! -d "$app_path" ]]; then
    echo "Simulator app not found: $app_path" >&2
    exit 66
fi

if [[ -z "$rocketsim_cli" ]]; then
    if command -v rocketsim >/dev/null 2>&1; then
        rocketsim_cli="$(command -v rocketsim)"
    elif [[ -x /opt/homebrew/bin/rocketsim ]]; then
        rocketsim_cli="/opt/homebrew/bin/rocketsim"
    elif [[ -x /Applications/RocketSim.app/Contents/Helpers/rocketsim ]]; then
        rocketsim_cli="/Applications/RocketSim.app/Contents/Helpers/rocketsim"
    else
        echo "RocketSim CLI not found. Install it from RocketSim > Settings > CLI & Agent." >&2
        exit 69
    fi
fi

mkdir -p "$screenshots_dir" "$videos_dir"

stop_recording() {
    if [[ -n "$recording_pid" ]] && kill -0 "$recording_pid" 2>/dev/null; then
        kill -INT "$recording_pid"
        local recording_status=0
        wait "$recording_pid" || recording_status=$?
        if [[ "$recording_status" -ne 0 || ! -s "$recording_path" ]]; then
            echo "RocketSim did not finalize ${recording_path}." >&2
            if [[ -f "$recording_log" ]]; then
                sed -n '1,120p' "$recording_log" >&2
            fi
            return 1
        fi
    fi
    recording_pid=""
    recording_path=""
}

trap stop_recording EXIT INT TERM

launch_fixture() {
    local screen="$1"
    local theme="$2"
    local pet="$3"
    local seed="$4"
    local autoplay="${5:-false}"
    local arguments=(
        --uitesting
        --screenshot-mode
        --screenshot-screen "$screen"
        --screenshot-theme "$theme"
        --screenshot-pet "$pet"
        --screenshot-seed "$seed"
        --screenshot-record-audio
    )

    if [[ "$autoplay" == "true" ]]; then
        arguments+=(--screenshot-autoplay)
    fi

    xcrun simctl launch --terminate-running-process \
        "$device_udid" "$bundle_id" "${arguments[@]}" >/dev/null
}

take_screenshot() {
    local filename="$1"
    xcrun simctl io "$device_udid" screenshot "${screenshots_dir}/${filename}"
}

start_recording() {
    local filename="$1"
    recording_log="${videos_dir}/${filename%.mp4}.rocketsim.log"
    recording_path="${videos_dir}/${filename}"
    "$rocketsim_cli" video record \
        --udid "$device_udid" \
        --fps 60 \
        >"$recording_path" \
        2>"$recording_log" &
    recording_pid=$!
    sleep 1
}

if ! xcrun simctl boot "$device_udid" 2>/dev/null; then
    true
fi
xcrun simctl bootstatus "$device_udid" -b
xcrun simctl status_bar "$device_udid" override \
    --time 09:41 \
    --batteryState charged \
    --batteryLevel 100 \
    --wifiBars 3 \
    --cellularMode active \
    --cellularBars 4
xcrun simctl install "$device_udid" "$app_path"

launch_fixture menu pixel none 1001
sleep 5
take_screenshot "01-menu-pixel-no-pet.png"

launch_fixture themes pixel none 1002
sleep 8
take_screenshot "05-themes-pixel.png"

launch_fixture pets pixel foka 1003
sleep 8
take_screenshot "06-pet-shop-pixel.png"

launch_fixture menu pixel foka 1004 true
sleep 4.2
take_screenshot "07-menu-pixel-foka.png"

launch_fixture menu classic misha 1005 true
sleep 4.2
take_screenshot "09-menu-default-misha.png"

launch_fixture leaderboard pixel none 1006
sleep 5
take_screenshot "11-leaderboard-pixel.png"

launch_fixture profile pixel none 1007
sleep 4
take_screenshot "12-profile-signed-out-pixel.png"

launch_fixture achievements pixel none 1008
sleep 5
take_screenshot "13-achievements-pixel.png"

launch_fixture arcade pixel none 2001 true
start_recording "${device_label}-arcade-pixel-no-pet-autoplay.mp4"
sleep 5
take_screenshot "02-arcade-1x1-pixel-no-pet-a.png"
sleep 1
take_screenshot "02-arcade-1x1-pixel-no-pet-b.png"
sleep 3
take_screenshot "03-arcade-2x2-pixel-no-pet-a.png"
sleep 1
take_screenshot "03-arcade-2x2-pixel-no-pet-b.png"
stop_recording
sleep 40
start_recording "${device_label}-arcade-4x4-pixel-no-pet-autoplay.mp4"
sleep 3
take_screenshot "04-arcade-4x4-pixel-no-pet-a.png"
sleep 1
take_screenshot "04-arcade-4x4-pixel-no-pet-b.png"
sleep 3
stop_recording

launch_fixture arcade pixel foka 2002 true
sleep 49
start_recording "${device_label}-arcade-pixel-foka-autoplay.mp4"
sleep 4
take_screenshot "08-arcade-4x4-pixel-foka-a.png"
sleep 1
take_screenshot "08-arcade-4x4-pixel-foka-b.png"
sleep 3
stop_recording

launch_fixture zen classic misha 2003 true
start_recording "${device_label}-zen-default-misha-autoplay.mp4"
sleep 8
take_screenshot "10-zen-2x2-default-misha-a.png"
sleep 1
take_screenshot "10-zen-2x2-default-misha-b.png"
sleep 2
stop_recording

echo "Capture candidates written to ${screenshots_dir}"
echo "RocketSim MP4 recordings with fixture audio enabled written to ${videos_dir}"
