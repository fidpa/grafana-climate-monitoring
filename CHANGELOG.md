# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [0.1.3] - 2026-08-28: GitHub identifies the project as MIT-licensed

### Changed

- **The repository page shows the MIT licence, and licence-filtered searches
  find the project.** `LICENSE` carried the repository URL on its own line
  under the copyright notice. GitHub reads a licence text with an extra line as
  modified and reports `NOASSERTION`, which leaves the licence field on the
  repository page empty. The line is gone; the MIT text and the copyright
  notice are byte-for-byte unchanged, and the URL is still in `README.md`.

## [0.1.2] — 2026-08-12

### Fixed

- **Both reader scripts are now executable in the repository itself**
  (`chmod 0755` on `scripts/fetch-outdoor-temp.sh` and
  `scripts/read-usb-temp-sensor.sh`). `docs/INSTALL.md` already sets the mode
  explicitly via `install -m 0755`, so a systemd-based install was never
  affected — but running either script directly from a checkout (`./scripts/
  read-usb-temp-sensor.sh`) failed with "Permission denied" until now.

## [0.1.1] — 2026-08-08

Housekeeping only. Every file this project deploys — the reader scripts, the
systemd units, the alert rules, the dashboard JSON, the Grafana provisioning and
the Alertmanager example — is byte-identical to v0.1.0. Upgrading changes nothing
on a running installation.

### Changed

- **The README heading now reads "Grafana Climate Monitoring".** It previously
  repeated the repository slug verbatim.
- **The CI validator images are pinned** to `prom/prometheus:v3.13.2` and
  `prom/alertmanager:v0.33.1` instead of tracking `:latest`. Both gates run
  upstream containers, so a new Prometheus or Alertmanager release could turn
  them red on an unchanged repository — the gate would then be reporting on
  upstream rather than on the commit. Bumping the pins is now a deliberate step,
  and a finding that appears after a bump is a real one. Verified before pinning:
  `promtool check rules` reports the same 4 rules, and `amtool check-config`
  reports the same config plus template.
- **The lint workflow can be triggered by hand** (`workflow_dispatch`). Until now
  it ran only on push and pull request, so re-validating an already-pushed commit
  would have required an empty commit.

### Fixed

- **The lint workflow now actually runs.** From the repository's creation until
  2026-08-08 GitHub had never registered it: the Actions API reported zero
  workflows and zero runs, and the Lint badge in the README returned HTTP 404 —
  despite Actions being enabled and `.github/workflows/lint.yml` sitting on
  `main` since the initial commit. Pushing a commit that touches the workflow
  file registered it; all five jobs (ShellCheck, YAML, Dashboard JSON, PromQL
  rules, Alertmanager config) pass, and the badge now reads `passing`. The five
  checks were previously only ever run locally.

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

[0.1.3]: https://github.com/fidpa/grafana-climate-monitoring/releases/tag/v0.1.3
[0.1.2]: https://github.com/fidpa/grafana-climate-monitoring/releases/tag/v0.1.2
[0.1.1]: https://github.com/fidpa/grafana-climate-monitoring/releases/tag/v0.1.1
[0.1.0]: https://github.com/fidpa/grafana-climate-monitoring/releases/tag/v0.1.0
