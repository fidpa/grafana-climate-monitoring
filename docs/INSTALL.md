# Installation

This walks through a full deployment. It assumes you already run Prometheus,
Grafana, and `node_exporter` **with the textfile collector enabled**. If you do
not, set those up first — this project plugs into them, it does not replace them.

Placeholders below use RFC 5737 / `example.com`. Replace them with your own.

## Prerequisites

- `node_exporter` started with the textfile collector, e.g.
  `--collector.textfile.directory=/var/lib/node_exporter/textfile_collector`
- Prometheus scraping that node_exporter, with a `rule_files:` entry you can
  extend.
- Grafana with file-based provisioning enabled (the default).
- On the sensor host: `bash`, `curl`, `jq`, `stty`, GNU `coreutils`.

## 1. Deploy the reader scripts

On the host physically near the rack (the one with the USB probe):

```bash
sudo install -m 0755 scripts/read-usb-temp-sensor.sh /usr/local/sbin/
sudo install -m 0755 scripts/fetch-outdoor-temp.sh   /usr/local/sbin/

# Set your location in the outdoor unit (see systemd/climate-outdoor-temp.service)
sudo install -m 0644 systemd/climate-usb-sensor.service   /etc/systemd/system/
sudo install -m 0644 systemd/climate-usb-sensor.timer     /etc/systemd/system/
sudo install -m 0644 systemd/climate-outdoor-temp.service /etc/systemd/system/
sudo install -m 0644 systemd/climate-outdoor-temp.timer   /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable --now climate-usb-sensor.timer climate-outdoor-temp.timer
```

Verify the metrics appear:

```bash
sudo systemctl start climate-usb-sensor.service   # run once now
cat /var/lib/node_exporter/textfile_collector/climate_intake.prom
curl -s localhost:9100/metrics | grep -E 'climate_(intake|outdoor)_'
```

You should see `climate_intake_temp_celsius`, `climate_intake_fetch_success 1`,
and a fresh `climate_intake_last_check_timestamp_seconds`.

## 2. Load the alert rules

```bash
sudo install -m 0644 prometheus/alerts/climate-alerts.yml /etc/prometheus/rules/
```

Add the file to `prometheus.yml` if it is not already covered by a glob:

```yaml
rule_files:
  - /etc/prometheus/rules/climate-alerts.yml
```

Edit the thresholds and the `RoomTempHigh` label matcher (`YOUR_CHIP` /
`YOUR_SENSOR`) to match your hardware — see [HARDWARE.md](HARDWARE.md). Then:

```bash
promtool check rules /etc/prometheus/rules/climate-alerts.yml
sudo systemctl reload prometheus
```

## 3. Provision Grafana

```bash
# Datasources (uid is pinned — see the file header for why this matters)
sudo install -m 0644 grafana/provisioning/datasources/prometheus.yaml \
  /etc/grafana/provisioning/datasources/
sudo install -m 0644 grafana/provisioning/datasources/infinity.yaml \
  /etc/grafana/provisioning/datasources/

# Dashboard provider + the dashboard itself
sudo install -m 0644 grafana/provisioning/dashboards/climate.yaml \
  /etc/grafana/provisioning/dashboards/
sudo install -d /var/lib/grafana/dashboards
sudo install -m 0644 grafana/dashboards/climate.json /var/lib/grafana/dashboards/

# The Infinity plugin powers the forecast table
sudo grafana-cli plugins install yesoreyeram-infinity-datasource
sudo systemctl restart grafana-server
```

Adjust the Prometheus datasource `url:` in `prometheus.yaml` if Prometheus is
not on `localhost:9090`.

> **Set the forecast location too.** The "Daily maximum forecast" panel queries
> Open-Meteo directly and has its coordinates baked into `climate.json` — it is
> **independent** of the `LATITUDE`/`LONGITUDE` env vars, which only drive the
> Prometheus-fed "outdoor now" and history panels. Edit the panel's `url` field
> in `climate.json` to your own latitude/longitude, or the forecast will keep
> showing the default (Berlin) location while everything else shows yours.

## 4. Open the dashboard

Browse to your Grafana, open **Server Room Climate** (folder *Climate*), and:

1. Pick your host in the **node_exporter host** dropdown.
2. Set the **room hwmon selector** textbox to your chip/sensor.

The intake, outdoor-now, and forecast panels populate on their own once the
timers have run.

## 5. E-mail alerts (optional)

The alert rules from step 2 fire inside Prometheus on their own. To turn a
firing alert into a layperson-friendly e-mail — subject, current value vs.
threshold, what-to-do text, and a one-click **Open dashboard** button — route
Prometheus to Alertmanager and use the templates in `alertmanager/`.

```bash
# 1) Deploy the template FIRST (Alertmanager and amtool parse it with the config)
sudo install -d /etc/alertmanager/templates
sudo install -m 0644 alertmanager/templates/climate-email.tmpl \
  /etc/alertmanager/templates/

# 2) Deploy the config, then edit SMTP settings + recipients in it
sudo install -m 0644 alertmanager/alertmanager.example.yml \
  /etc/alertmanager/alertmanager.yml

# 3) Provide the SMTP password out-of-band (never in the committed config)
printf '%s' 'YOUR_SMTP_PASSWORD' | sudo tee /etc/alertmanager/smtp_password >/dev/null
sudo chmod 0600 /etc/alertmanager/smtp_password

# 4) Validate and reload
amtool check-config /etc/alertmanager/alertmanager.yml
sudo systemctl reload alertmanager
```

Point Prometheus at Alertmanager (once, in `prometheus.yml`):

```yaml
alerting:
  alertmanagers:
    - static_configs:
        - targets: ['localhost:9093']
```

The e-mail rendering keys off the same annotations the rules already set
(`summary`, `value`, `threshold`, `description`, `dashboard_url`) — the value
box and the dashboard button appear only for alerts that provide them. Set
`dashboard_url` in `IntakeTempHigh` (see `prometheus/alerts/climate-alerts.yml`)
to your own Grafana URL so the button deep-links to the dashboard.

> **Timestamps:** the template formats times with `.Local`. If the Alertmanager
> host runs on UTC, set `Environment=TZ=Europe/Berlin` (or your zone) on the
> service so mails show local time.

## Troubleshooting

Something not showing up? See **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** — a
symptom-first reference (No data, empty forecast table, `IntakeSensorDown`,
missing e-mails, …) with a verify step and fix for each case.
