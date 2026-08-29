# Grafana Climate Monitoring

![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)
![Lint](https://github.com/fidpa/grafana-climate-monitoring/actions/workflows/lint.yml/badge.svg)
![Bash](https://img.shields.io/badge/Bash-3.2%2B-blue?logo=gnu-bash)
![Grafana](https://img.shields.io/badge/Grafana-10%2B-F46800?logo=grafana&logoColor=white)
![Prometheus](https://img.shields.io/badge/Prometheus-node__exporter-E6522C?logo=prometheus&logoColor=white)

**Know before the room cooks.** A small, self-hosted setup that watches a server
room, a network cabinet, a homelab shelf or a garage rack for a cooling failure
and catches it while the room average is still unchanged, using a Grafana
dashboard, Prometheus alerts, and a USB temperature probe in the AC cold-air
stream.

![Server Room Climate dashboard](docs/img/dashboard.png)

## The idea

Room-average temperature is a *lagging* signal: by the time the whole room is
warm, the air conditioner has been dead for a while. The trick is to put a USB
probe **directly in the cold-air stream** of the AC unit. When cooling fails,
that stream warms within seconds, while the room average is still where it was.
What makes the difference is the placement, not the sensor;
[docs/HARDWARE.md](docs/HARDWARE.md) describes where the probe has to sit.

This project combines three temperature sources into one picture:

- **Cold-air intake** (USB probe): the *fast* cooling-failure signal.
- **Room air** (an on-board `hwmon` sensor node_exporter already sees): the
  *broad* signal.
- **Outdoor** (Open-Meteo, free, no API key): *context*. Is the room warming
  because the AC failed, or because it is 38 °C outside?

Everything is plain files: shell scripts, systemd timers, a Prometheus rules
file, and a Grafana dashboard JSON. No database, no daemon of its own, no
account anywhere; the file list further down is the whole thing.

## What this is not

- **Not a control system.** It observes and alerts. Nothing here switches a fan,
  throttles a host, or talks to the AC unit.
- **Not redundant.** One probe, one room sensor. A probe that slips out of the
  cold-air stream still reports a plausible number, and no second source
  contradicts it.
- **Not a calibrated alerting profile.** The thresholds in the shipped rules
  (30 °C room, 25 °C intake) come from one rack and are placeholders. Calibrate
  them as described under [Alerts](#alerts).
- **Not portable beyond Linux with GNU coreutils.** `read-usb-temp-sensor.sh`
  uses `head -n -1`, which BSD and macOS `head` reject. The Bash 3.2 badge is
  about Bash syntax, not about the userland around it.
- **Not a driver for arbitrary probes.** The reader assumes a thermometer that
  streams bare float lines by itself at 9600 baud, 8N1 (typical for CP2102N,
  CH340 and FTDI probes). A probe that answers queries instead needs its own
  `read_temp` implementation.

One blind spot is worth knowing before you rely on the setup: `IntakeSensorDown`
detects a reader that *stopped*, not one that never started. Until the `.prom`
file has been written once, both sides of its expression return an empty vector
and the alert stays silent while the intake panels read "No sensor". The rule
file states this at the rule itself.

## How it works

```
╔══ host near the rack ════════════════════════════════════╗
║                                                          ║
║  USB probe ──▶ ╭──────────────────────╮                  ║
║  (AC stream)   │ read-usb-temp-sensor │──┐               ║
║                ╰──────────────────────╯  │               ║
║                                          ▼   .prom        ║
║  Open-Meteo ─▶ ╭──────────────────────╮  textfile        ║
║  (outdoor)     │ fetch-outdoor-temp   │─▶ collector       ║
║                ╰──────────────────────╯  │               ║
║                                          ▼               ║
║  on-board hwmon ──────────────▶ ┌──────────────────┐     ║
║  (room air)                     │ node_exporter    │     ║
║                                 │ :9100            │     ║
║                                 └────────┬─────────┘     ║
╚══════════════════════════════════════════│══════════════╝
                                           │ scrape
                                           ▼
                    ┌────────────┐   ┌────────────────┐
                    │ Prometheus │──▶│    Grafana     │
                    │ + alerts   │   │ climate board  │
                    └─────┬──────┘   └────────────────┘
                          │ fires
                          ▼
                    Alertmanager ──▶ your email / chat
```

## What's in the box

```
scripts/
  read-usb-temp-sensor.sh     USB serial probe -> Prometheus gauge
  fetch-outdoor-temp.sh       Open-Meteo -> Prometheus gauge
systemd/
  climate-usb-sensor.*        service + timer (every 60 s)
  climate-outdoor-temp.*      service + timer (every 15 min)
prometheus/alerts/
  climate-alerts.yml          RoomTempHigh, IntakeTempHigh, IntakeSensorDown,
                              OutdoorFetchStale
grafana/
  dashboards/climate.json     the dashboard
  provisioning/               datasources (pinned uid) + dashboard provider
alertmanager/                 optional e-mail alerting
  alertmanager.example.yml    route + receiver (SMTP placeholders)
  templates/                  layperson-friendly HTML/text mail template
docs/
  HARDWARE.md                 sensor choices, finding your hwmon sensor
  INSTALL.md                  full step-by-step deployment
  OPEN_METEO_GRAFANA.md       the forecast-table recipe (Infinity + JSONata)
  TROUBLESHOOTING.md          symptom, cause, fix
```

## Quick start

You need an existing Prometheus + Grafana + `node_exporter` (with the textfile
collector). Then, on the host near the rack:

```bash
sudo install -m 0755 scripts/*.sh /usr/local/sbin/
sudo install -m 0644 systemd/* /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now climate-usb-sensor.timer climate-outdoor-temp.timer
```

Load the alerts, provision the dashboard, set your location and sensor: the
full walkthrough is in **[docs/INSTALL.md](docs/INSTALL.md)**. If a panel stays
empty afterwards, **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** lists
the symptoms in the order they usually appear.

## Metrics

| Metric | Source | Meaning |
|---|---|---|
| `node_hwmon_temp_celsius` | node_exporter | room air (your chosen hwmon sensor) |
| `climate_intake_temp_celsius` | `read-usb-temp-sensor.sh` | AC cold-air stream |
| `climate_intake_fetch_success` | `read-usb-temp-sensor.sh` | last read ok (1) / failed (0) |
| `climate_intake_last_check_timestamp_seconds` | `read-usb-temp-sensor.sh` | freshness of the reading |
| `climate_outdoor_temp_celsius` | `fetch-outdoor-temp.sh` | outdoor reference |
| `climate_outdoor_fetch_success` | `fetch-outdoor-temp.sh` | last fetch ok (1) / failed (0) |
| `climate_outdoor_last_check_timestamp_seconds` | `fetch-outdoor-temp.sh` | freshness of the reference |

Each reader emits the same three gauges: the value, a success flag, and a
timestamp. The two extra gauges exist because the textfile collector has no
notion of staleness: it re-serves whatever the last `.prom` file said, for as
long as the file exists, so a plain "temperature is fine" check cannot tell a
cool room from a dead reader. `IntakeSensorDown` and `OutdoorFetchStale`
therefore combine a read-failure check with an age check.

## Alerts

| Alert | Fires when | Held for | Severity |
|---|---|---|---|
| `RoomTempHigh` | room air above 30 °C | 10 min | warning |
| `IntakeTempHigh` | AC cold-air stream above 25 °C | 10 min | warning |
| `IntakeSensorDown` | probe read failed, or reading older than 10 min | 2 min | warning |
| `OutdoorFetchStale` | fetch failed, or reference older than 1 h | 6 h | info |

The hold times are not uniform on purpose. `IntakeSensorDown` waits only 2
minutes because its staleness clause already carries 10, and stretching it
would delay the detection of a stopped reader twice over. `OutdoorFetchStale`
waits 6 hours because a missing context line puts nothing at risk.

The two temperature thresholds in `prometheus/alerts/climate-alerts.yml` are
starting points from one rack, not values you should adopt. Log a few days of
normal operation, then set them a few degrees above your own baseline.

For e-mail notifications, wire up Alertmanager with the optional templates in
`alertmanager/`: a layperson-friendly mail showing the current value, the
threshold, and a one-click dashboard button. See
**[docs/INSTALL.md](docs/INSTALL.md)** step 5.

## Configuration

Both scripts read their settings from environment variables (set them in the
systemd unit's `Environment=` lines):

| Variable | Default | Used by |
|---|---|---|
| `SENSOR_DEV` | unset (falls back to the glob) | USB reader |
| `SENSOR_DEV_GLOB` | `/dev/serial/by-id/*-if00-port0` | USB reader |
| `SENSOR_BAUD` | `9600` | USB reader |
| `READ_TIMEOUT` | `3` | USB reader |
| `LATITUDE` / `LONGITUDE` | `52.52` / `13.405` (Berlin city centre) | outdoor reader |
| `OPEN_METEO_MODEL` | `dwd-icon` (use `forecast` outside Central Europe) | outdoor reader |
| `TEXTFILE_DIR` | `/var/lib/node_exporter/textfile_collector` | both |
| `METRIC_PREFIX` | `climate_intake` / `climate_outdoor` | both |

Three values are fixed in the scripts themselves: the sanity bounds `TEMP_MIN`
(-40) and `TEMP_MAX` (100) in `scripts/read-usb-temp-sensor.sh`, which reject
electrical glitches, and the curl `TIMEOUT` (10 s) in
`scripts/fetch-outdoor-temp.sh`. A probe operating outside that range, or a slow
link, needs an edit in the script.

Three further settings are shared between files, so changing one means changing
all of them:

- **`METRIC_PREFIX`** is settable per reader, but the metric names are also
  hardcoded in `prometheus/alerts/climate-alerts.yml` and
  `grafana/dashboards/climate.json`. Change it in one place, change it in all
  three.
- **Your room hwmon selector** starts out as the placeholder
  `chip="YOUR_CHIP",sensor="YOUR_SENSOR"` in two places: the `room_sensor`
  textbox variable of the dashboard, and the matcher of the `RoomTempHigh`
  rule. [docs/HARDWARE.md](docs/HARDWARE.md) shows how to find your own.
- **The forecast table's location** lives in the dashboard JSON, not in
  `LATITUDE`/`LONGITUDE` (those only drive the Prometheus-fed panels). Edit the
  `url` field of the "Daily maximum forecast" panel to your own coordinates.

## Requirements

- Prometheus, Grafana (10+, because the forecast table uses the `cellOptions`
  table API introduced in 10.0), and `node_exporter` with the textfile collector
- `bash`, `curl`, `jq`, `awk`, `stty`, and GNU coreutils (`timeout`, and
  `head -n -1`, which BSD `head` does not support) on the sensor host
- Grafana plugin `yesoreyeram-infinity-datasource` (only for the forecast table)

## Third-party parts

- **Outdoor data** comes from [Open-Meteo](https://open-meteo.com), queried
  live, not redistributed here. The free tier needs no API key; check their
  terms before using it commercially.
- **The forecast table** needs the
  [Infinity datasource](https://grafana.com/grafana/plugins/yesoreyeram-infinity-datasource/),
  a third-party Grafana plugin you install yourself. Its JSONata selector, and
  why the weekday is computed with Zeller's congruence, are explained in
  [docs/OPEN_METEO_GRAFANA.md](docs/OPEN_METEO_GRAFANA.md).
- **The screenshot** shows the dashboard this repository ships, captured on the
  author's own rack. It carries no hostname or location because the dashboard
  reads both from variables; [docs/img/README.md](docs/img/README.md) holds the
  checklist for replacing it.

## License

MIT, see [LICENSE](LICENSE).
