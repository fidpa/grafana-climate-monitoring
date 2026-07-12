# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [0.1.0] — 2026-07-12

### Added
- USB serial temperature sensor reader (`read-usb-temp-sensor.sh`) with atomic
  `.prom` writes, truncated-frame handling, and liveness gauges.
- Open-Meteo outdoor temperature reader (`fetch-outdoor-temp.sh`).
- Grafana dashboard (`climate.json`): room air, cooling-intake, outdoor
  reference, and a 7-day forecast table via the Infinity datasource.
- Prometheus alert rules: `RoomTempHigh`, `IntakeTempHigh`, `IntakeSensorDown`
  (fetch-failure **or** staleness), `OutdoorFetchStale`.
- systemd service + timer units for both readers.
- Grafana provisioning for Prometheus (pinned uid) and Infinity datasources.
- Optional Alertmanager e-mail alerting: example config
  (`alertmanager/alertmanager.example.yml`) and a layperson-friendly HTML/text
  template (`alertmanager/templates/climate-email.tmpl`) rendering current
  value vs. threshold, what-to-do text, and a dashboard button.

[0.1.0]: https://github.com/fidpa/grafana-climate-monitoring/releases/tag/v0.1.0
