#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Marc Allgeier (fidpa)
# https://github.com/fidpa/grafana-climate-monitoring
#
# read-usb-temp-sensor.sh — Read a temperature from a self-streaming USB serial
# thermometer and publish it as a Prometheus gauge into the node_exporter
# textfile collector.
#
# Designed as an early-warning probe for a cooling failure: place the sensor in
# the cold-air stream of the AC unit. When cooling fails, that stream warms up
# within seconds — long before the room-average temperature moves. Pair this
# with the IntakeTempHigh alert (see prometheus/alerts/climate-alerts.yml).
#
# Sensor protocol assumed here (typical for CP2102N / CH340 / FTDI probes):
#   9600 baud, 8N1, raw. The device streams lines of the form "<float>\r\n" (°C)
#   on its own, dozens of times per second. No query/command is sent.
#   Adjust SENSOR_BAUD (and read_temp parsing) if your device differs.
#
# Why root: /dev/ttyUSB* is usually root:dialout, and the textfile collector
# directory is typically root-owned. Run via a systemd oneshot as root (see
# systemd/climate-usb-sensor.service). Soft-fail: a sensor outage writes
# fetch_success=0 and exits non-zero, but blocks nothing downstream.
#
# Configuration (environment variables, all optional):
#   SENSOR_DEV        Explicit device path. Overrides SENSOR_DEV_GLOB.
#   SENSOR_DEV_GLOB   Glob for a stable by-id path. Default matches any
#                     single-port USB-serial adapter. Narrow it (e.g.
#                     '*CP2102N*-if00-port0') if you have several adapters.
#   SENSOR_BAUD       Serial baud rate. Default 9600.
#   READ_TIMEOUT      Seconds to sample the stream. Default 3. Widen it for a
#                     slow-streaming sensor (needs >= 3 lines within the window).
#   TEXTFILE_DIR      node_exporter textfile collector dir.
#                     Default /var/lib/node_exporter/textfile_collector.
#   METRIC_PREFIX     Metric name prefix. Default climate_intake. NOTE: changing
#                     it also requires matching edits in the alert rules and the
#                     Grafana dashboard, which hardcode the metric names.

set -uo pipefail

readonly SENSOR_DEV_GLOB="${SENSOR_DEV_GLOB:-/dev/serial/by-id/*-if00-port0}"
readonly BAUD="${SENSOR_BAUD:-9600}"
readonly READ_TIMEOUT="${READ_TIMEOUT:-3}"
readonly TEMP_MIN=-40
readonly TEMP_MAX=100
readonly METRIC_PREFIX="${METRIC_PREFIX:-climate_intake}"

readonly TEXTFILE_DIR="${TEXTFILE_DIR:-/var/lib/node_exporter/textfile_collector}"
readonly PROM_FILE="${TEXTFILE_DIR}/${METRIC_PREFIX}.prom"
readonly PROM_TMP="${PROM_FILE}.tmp.$$"

# Resolve the device path. A stable /dev/serial/by-id/ glob survives ttyUSB
# renumbering and sensor swaps far better than a hard-coded /dev/ttyUSB0.
DEV="${SENSOR_DEV:-}"
if [[ -z "$DEV" ]]; then
    for cand in $SENSOR_DEV_GLOB; do
        [[ -e "$cand" ]] && { DEV="$cand"; break; }
    done
fi

# Orphan protection: remove the temp file if we are killed between ">" and "mv".
# After a successful mv, PROM_TMP is already gone, so rm -f is a no-op.
trap 'rm -f "$PROM_TMP" 2>/dev/null' EXIT INT TERM

log() {
    echo "[$(date +%Y-%m-%dT%H:%M:%S%z)] $*"
}

# Atomic write: build the full .prom in a temp file, then rename into place.
# node_exporter never sees a half-written file, and the two liveness gauges
# (fetch_success + last_check_timestamp) let an alert distinguish "sensor read
# failed" and "reader stopped entirely" from a genuinely low reading.
write_prom() {
    local success="$1"
    local temp="$2"

    mkdir -p "$TEXTFILE_DIR" 2>/dev/null || true

    {
        echo "# HELP ${METRIC_PREFIX}_temp_celsius Temperature at the AC cold-air intake probe (USB serial sensor)."
        echo "# TYPE ${METRIC_PREFIX}_temp_celsius gauge"
        [[ -n "$temp" ]] && echo "${METRIC_PREFIX}_temp_celsius ${temp}"
        echo "# HELP ${METRIC_PREFIX}_fetch_success Last sensor read succeeded (1) or failed (0)."
        echo "# TYPE ${METRIC_PREFIX}_fetch_success gauge"
        echo "${METRIC_PREFIX}_fetch_success ${success}"
        echo "# HELP ${METRIC_PREFIX}_last_check_timestamp_seconds Unix timestamp of the last read attempt."
        echo "# TYPE ${METRIC_PREFIX}_last_check_timestamp_seconds gauge"
        echo "${METRIC_PREFIX}_last_check_timestamp_seconds $(date +%s)"
    } > "$PROM_TMP"
    mv "$PROM_TMP" "$PROM_FILE"
}

# Read one complete, valid float line out of the free-running sensor stream.
read_temp() {
    [[ -z "$DEV" || ! -e "$DEV" ]] && return 1
    stty -F "$DEV" "$BAUD" raw -echo 2>/dev/null || return 1

    # Grab a short burst, strip CR, keep only pure float lines.
    local readings
    readings=$(timeout "$READ_TIMEOUT" cat "$DEV" 2>/dev/null \
        | tr -d '\r' \
        | grep -E '^-?[0-9]+(\.[0-9]+)?$')
    [[ -z "$readings" ]] && return 1

    # Discard the first AND last line — both may be truncated: the first because
    # we started reading mid-stream, the last because the timeout killed cat
    # mid-frame. The grep above rejects format garbage, but a chopped "16" out of
    # "16.5" would still look valid. The newest GUARANTEED-complete line is the
    # second-to-last. (head -n -1 is GNU coreutils.)
    local temp
    temp=$(printf '%s\n' "$readings" | tail -n +2 | head -n -1 | tail -1)
    [[ -z "$temp" ]] && return 1

    # Sanity bound against electrical glitches.
    awk -v t="$temp" -v lo="$TEMP_MIN" -v hi="$TEMP_MAX" \
        'BEGIN { exit !(t >= lo && t <= hi) }' || return 1

    printf '%s' "$temp"
}

if [[ -z "$DEV" ]]; then
    log "ERROR: no USB serial sensor found (glob: ${SENSOR_DEV_GLOB})"
    write_prom 0 ""
    exit 1
fi

temperature=$(read_temp)
read_exit=$?

if [[ $read_exit -ne 0 || -z "$temperature" ]]; then
    log "ERROR: no valid reading from ${DEV}"
    write_prom 0 ""
    exit 1
fi

log "OK: intake ${temperature}°C (${DEV})"
write_prom 1 "$temperature"
exit 0
