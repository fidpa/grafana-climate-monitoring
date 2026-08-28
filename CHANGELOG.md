# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [0.1.5] - 2026-08-28: The licence entry points at the file that carries the project address

### Fixed

- **The `[0.1.4]` note on the removed licence line named the wrong file.** The
  line taken out of `LICENSE` was the bare project address, and `README.md`
  carries that address only as the prefix of the Lint badge image, which is a
  path to an SVG and not a link a reader can follow. The address is in
  `scripts/fetch-outdoor-temp.sh`, `scripts/read-usb-temp-sensor.sh` and the
  four unit files under `systemd/`, where `Documentation=` points at it.

## [0.1.5] - 2026-08-28: Documentation matches what the scripts and rules actually do

### Fixed

- **The three settings that are not environment variables are now named as
  such.** `README.md` said both readers are configured entirely through
  environment variables. `TEMP_MIN` (-40) and `TEMP_MAX` (100) in
  `scripts/read-usb-temp-sensor.sh` and `TIMEOUT` (10) in
  `scripts/fetch-outdoor-temp.sh` are `readonly` without an environment fallback,
  so a probe operating outside that range, or a slow link, needs an edit in the
  script. The README and both script headers say where.
- **The lead time in the README is no longer a number nobody measured.** The hero
  and the introduction promised "minutes before a room thermometer would" and
  "minutes of head start". What the project can show is the physical one:
  `docs/HARDWARE.md` documents that the cold-air stream warms within seconds,
  which is the sensor reaction, not a measured lead over the room average. Both
  sentences now say what they can show, that the intake reading moves while the
  room average is still where it was.
- **The e-mail template no longer claims all four rules carry the same
  annotations.** Its header said the `value`, `threshold` and `dashboard_url`
  annotations are "exactly the annotations used by
  `prometheus/alerts/climate-alerts.yml`". Two of the four rules set `value` and
  `threshold` (`RoomTempHigh`, `IntakeTempHigh`) and one sets `dashboard_url`
  (`IntakeTempHigh`); `IntakeSensorDown` and `OutdoorFetchStale` carry summary and
  description only. The rendering was always conditional and is unchanged; only
  the comment was wrong.

## [0.1.4] - 2026-08-28: Release pages carry the changelog section they belong to

The release pages and this file had grown apart. Every published body was an
edited retelling of its changelog section, with its own `### Highlights`
structure, so a correction to one of them did not reach the other. This
release makes the changelog the single source for both, and moves the release
title into the section heading so the CI can read it from there.

The older sections were checked against the tags they describe. Every measured
value, path and identifier in them is unchanged; what changed is the wording and
the typography.

### Added

- **A tag push now creates the release.** `.github/workflows/release.yml` cuts
  the section for the pushed tag out of `CHANGELOG.md`, takes the headline from
  the heading and hands both to `softprops/action-gh-release` as `name` and
  `body_path`. Until now the title and the body were typed by hand at
  `gh release create`, which is why no two of them followed the same form.

### Changed

- **Every release page carries the verbatim changelog section of its version.**
  The bodies of `v0.1.0` through `v0.1.3` were replaced with the sections below,
  so a correction to this file reaches the release page with the next edit
  instead of living in two versions.
- **Release titles name what a version changes.** The headline lives in the
  section heading (`## [X.Y.Z] - YYYY-MM-DD: <headline>`) and is the only source
  the workflow reads, so title and body cannot disagree.
- **The `v0.1.2` release page no longer claims the reader scripts are executable
  "again".** `scripts/read-usb-temp-sensor.sh` and `scripts/fetch-outdoor-temp.sh`
  were tracked as mode `0644` from the initial commit until `v0.1.2`, so there was
  no earlier state to return to. That release made them executable for the first
  time, and its title now says so.
- **The initial-release entries lead with what the setup gives an operator**
  rather than with the file that provides it. The files, metric names and alert
  names they cite are the same ones.
- **This file is plain ASCII.** The em dash stood for a colon, a parenthesis and
  a causal clause in turn; each occurrence is now the punctuation or the word it
  replaced.

## [0.1.3] - 2026-08-28: GitHub identifies the project as MIT-licensed

### Changed

- **The repository page shows the MIT licence, and licence-filtered searches
  find the project.** `LICENSE` carried the repository URL on its own line
  under the copyright notice. GitHub reads a licence text with an extra line as
  modified and reports `NOASSERTION`, which leaves the licence field on the
  repository page empty. The line is gone; the MIT text and the copyright
  notice are byte-for-byte unchanged, and the URL is still in `README.md`.

## [0.1.2] - 2026-08-12: Reader scripts run straight from a checkout

### Fixed

- **Both reader scripts are now executable in the repository itself**
  (`chmod 0755` on `scripts/fetch-outdoor-temp.sh` and
  `scripts/read-usb-temp-sensor.sh`). `docs/INSTALL.md` already sets the mode
  explicitly via `install -m 0755`, so a systemd-based install was never
  affected; running either script directly from a checkout
  (`./scripts/read-usb-temp-sensor.sh`) failed with "Permission denied" until
  now.

## [0.1.1] - 2026-08-08: Lint pipeline in service and validator images pinned

Housekeeping only. Every file this project deploys (the reader scripts, the
systemd units, the alert rules, the dashboard JSON, the Grafana provisioning and
the Alertmanager example) is byte-identical to v0.1.0. Upgrading changes nothing
on a running installation.

### Changed

- **The README heading now reads "Grafana Climate Monitoring".** It previously
  repeated the repository slug verbatim.
- **The CI validator images are pinned** to `prom/prometheus:v3.13.2` and
  `prom/alertmanager:v0.33.1` instead of tracking `:latest`. Both gates run
  upstream containers, so a new Prometheus or Alertmanager release could turn
  them red on an unchanged repository, and the gate would then be reporting on
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
  workflows and zero runs, and the Lint badge in the README returned HTTP 404,
  despite Actions being enabled and `.github/workflows/lint.yml` sitting on
  `main` since the initial commit. Pushing a commit that touches the workflow
  file registered it; all five jobs (ShellCheck, YAML, Dashboard JSON, PromQL
  rules, Alertmanager config) pass, and the badge now reads `passing`. The five
  checks were previously only ever run locally.

## [0.1.0] - 2026-07-12: Server-room climate monitoring

### Added

- **A warming AC cold-air stream becomes a Prometheus gauge.**
  `scripts/read-usb-temp-sensor.sh` reads a self-streaming USB serial
  thermometer and publishes `climate_intake_temp_celsius` into the node_exporter
  textfile collector. The `.prom` file is built in a temp file and renamed into
  place, so node_exporter never sees a half-written one; the first and the last
  line of each sampling burst are discarded because both can be cut mid-frame.
- **A dead reader is distinguishable from a low reading.** Both readers write two
  liveness gauges next to the value, `*_fetch_success` and
  `*_last_check_timestamp_seconds`, which is what lets an alert tell "the read
  failed" and "the reader stopped" apart.
- **Outdoor temperature arrives as context, without an API key.**
  `scripts/fetch-outdoor-temp.sh` fetches the current value from Open-Meteo and
  publishes `climate_outdoor_temp_celsius`.
- **One dashboard holds room air, cooling intake and outdoor reference.**
  `grafana/dashboards/climate.json` carries the panels for all three sources plus
  a daily-maximum forecast table fed by the Infinity datasource
  (`forecast_days=8`, which yields seven or eight real rows depending on the
  model run; see `docs/OPEN_METEO_GRAFANA.md`).
- **Four alert rules cover the fast signal, the broad signal and a stopped
  reader.** `prometheus/alerts/climate-alerts.yml` ships `RoomTempHigh`,
  `IntakeTempHigh`, `IntakeSensorDown` (fetch failure **or** staleness) and
  `OutdoorFetchStale`.
- **Both readers are driven by systemd timers.**
  `systemd/climate-usb-sensor.timer` fires every 60 seconds and
  `systemd/climate-outdoor-temp.timer` every 15 minutes; only the outdoor unit
  orders on `network-online.target`, because the sensor read is local serial I/O.
- **A provisioned dashboard finds its datasource without manual editing.**
  `grafana/provisioning/datasources/prometheus.yaml` pins `uid: prometheus`,
  which is the uid the dashboard JSON references; `infinity.yaml` provisions the
  forecast datasource the same way.
- **Alertmanager can turn a firing alert into a mail a non-engineer
  understands.** `alertmanager/alertmanager.example.yml` carries route and
  receiver with SMTP placeholders, and
  `alertmanager/templates/climate-email.tmpl` renders an HTML and a text body: the
  `value` and `threshold` annotations where a rule sets them, the `description` as
  a what-to-do line, and a dashboard button where a rule sets `dashboard_url`.
  Both files are optional; the alert rules fire without them.

[0.1.5]: https://github.com/fidpa/grafana-climate-monitoring/releases/tag/v0.1.5
[0.1.5]: https://github.com/fidpa/grafana-climate-monitoring/releases/tag/v0.1.5
[0.1.4]: https://github.com/fidpa/grafana-climate-monitoring/releases/tag/v0.1.4
[0.1.3]: https://github.com/fidpa/grafana-climate-monitoring/releases/tag/v0.1.3
[0.1.2]: https://github.com/fidpa/grafana-climate-monitoring/releases/tag/v0.1.2
[0.1.1]: https://github.com/fidpa/grafana-climate-monitoring/releases/tag/v0.1.1
[0.1.0]: https://github.com/fidpa/grafana-climate-monitoring/releases/tag/v0.1.0
