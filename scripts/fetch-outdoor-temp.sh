#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Marc Allgeier (fidpa)
# https://github.com/fidpa/grafana-climate-monitoring
#
# fetch-outdoor-temp.sh — Fetch the current outdoor temperature for a location
# from the free Open-Meteo API and publish it as a Prometheus gauge into the
# node_exporter textfile collector.
#
# Purpose: a reference line next to the room temperature on the dashboard. It
# answers "is the room warming because the AC failed, or because it is 38 °C
# outside?" — context that turns a bare number into an interpretable signal.
#
# No API key, no rate limit for non-commercial use (Open-Meteo). Soft-fail: an
# API outage writes fetch_success=0 and exits non-zero, but blocks nothing.
#
# Configuration (environment variables, all optional):
#   LATITUDE / LONGITUDE  Location. Defaults to Berlin city centre — change to
#                         your own. Find yours at https://open-meteo.com or via
#                         any geocoder (OpenStreetMap/Nominatim).
#   OPEN_METEO_MODEL      API model endpoint. Default dwd-icon (Central Europe).
#                         Use 'forecast' for the global best-match model.
#   TEXTFILE_DIR          node_exporter textfile collector dir.
#   METRIC_PREFIX         Metric name prefix. Default climate_outdoor.

set -uo pipefail

readonly LATITUDE="${LATITUDE:-52.52}"
readonly LONGITUDE="${LONGITUDE:-13.405}"
readonly OPEN_METEO_MODEL="${OPEN_METEO_MODEL:-dwd-icon}"
readonly API_URL="https://api.open-meteo.com/v1/${OPEN_METEO_MODEL}?latitude=${LATITUDE}&longitude=${LONGITUDE}&current=temperature_2m&timezone=auto"
readonly TIMEOUT=10
readonly METRIC_PREFIX="${METRIC_PREFIX:-climate_outdoor}"

readonly TEXTFILE_DIR="${TEXTFILE_DIR:-/var/lib/node_exporter/textfile_collector}"
readonly PROM_FILE="${TEXTFILE_DIR}/${METRIC_PREFIX}.prom"
readonly PROM_TMP="${PROM_FILE}.tmp.$$"

# Orphan protection: remove the temp file if we are killed between ">" and "mv".
trap 'rm -f "$PROM_TMP" 2>/dev/null' EXIT INT TERM

log() {
    echo "[$(date +%Y-%m-%dT%H:%M:%S%z)] $*"
}

write_prom() {
    local success="$1"
    local temp="$2"

    mkdir -p "$TEXTFILE_DIR" 2>/dev/null || true

    {
        echo "# HELP ${METRIC_PREFIX}_temp_celsius Current outdoor temperature (Open-Meteo)."
        echo "# TYPE ${METRIC_PREFIX}_temp_celsius gauge"
        [[ -n "$temp" ]] && echo "${METRIC_PREFIX}_temp_celsius ${temp}"
        echo "# HELP ${METRIC_PREFIX}_fetch_success Last Open-Meteo fetch succeeded (1) or failed (0)."
        echo "# TYPE ${METRIC_PREFIX}_fetch_success gauge"
        echo "${METRIC_PREFIX}_fetch_success ${success}"
        echo "# HELP ${METRIC_PREFIX}_last_check_timestamp_seconds Unix timestamp of the last fetch attempt."
        echo "# TYPE ${METRIC_PREFIX}_last_check_timestamp_seconds gauge"
        echo "${METRIC_PREFIX}_last_check_timestamp_seconds $(date +%s)"
    } > "$PROM_TMP"
    mv "$PROM_TMP" "$PROM_FILE"
}

response=$(curl -s -m "$TIMEOUT" "$API_URL" 2>/dev/null)
curl_exit=$?

if [[ $curl_exit -ne 0 || -z "$response" ]]; then
    log "ERROR: Open-Meteo unreachable (curl exit: $curl_exit)"
    write_prom 0 ""
    exit 1
fi

temperature=$(echo "$response" | jq -r '.current.temperature_2m // empty' 2>/dev/null)

if [[ -z "$temperature" ]]; then
    log "ERROR: response contained no temperature: $response"
    write_prom 0 ""
    exit 1
fi

log "OK: outdoor ${temperature}°C"
write_prom 1 "$temperature"
exit 0
