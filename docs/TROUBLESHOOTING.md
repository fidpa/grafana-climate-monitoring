# Troubleshooting

A symptom-first reference. Each section starts with what you see, then gives the
likely cause, how to confirm it, and the fix.

---

## The room panels say "No data"

**Symptom:** The intake and outdoor panels work, but every *room air* panel is
empty, and `RoomTempHigh` never has data to evaluate.

**Likely cause:** The `room_sensor` dashboard variable is unset or points at a
chip/sensor your host does not expose. Room air comes from `node_hwmon_temp_celsius`,
and the exact `chip`/`sensor` labels differ per motherboard.

**Verify:**

```bash
# What hwmon labels does node_exporter actually export here?
curl -s localhost:9100/metrics | grep node_hwmon_temp_celsius
```

**Fix:** Set the **room hwmon selector** textbox on the dashboard, and the
`RoomTempHigh` matcher in `prometheus/alerts/climate-alerts.yml`, to a chip/sensor
from that output — see [HARDWARE.md](HARDWARE.md) for picking the right one.

---

## Every panel says "No data"

**Symptom:** Nothing renders — room, intake, and outdoor panels are all empty,
even though Prometheus clearly has the metrics.

**Likely cause:** The dashboard references the Prometheus datasource by `uid`,
and the provisioned datasource did not come up with `uid: prometheus`. This is
the single most common cause of an empty provisioned dashboard.

**Verify:** In Grafana, open **Connections → Data sources → Prometheus** and
check the UID in the URL, or confirm the provisioning file loaded at all.

**Fix:** Make sure `grafana/provisioning/datasources/prometheus.yaml` is the file
Grafana loaded (it pins `uid: prometheus`), then restart Grafana. Do not create a
second Prometheus datasource by hand — it will get a random UID.

---

## Intake panels show "No sensor" (no cold-air data)

**Symptom:** `climate_intake_*` metrics are missing or never update.

**Likely cause:** The reader has not produced a reading yet, or `SENSOR_DEV_GLOB`
does not match your probe.

**Verify:**

```bash
sudo systemctl start climate-usb-sensor.service   # run once now
cat /var/lib/node_exporter/textfile_collector/climate_intake.prom
journalctl -u climate-usb-sensor -n 30
ls -l /dev/serial/by-id/                           # is the probe there?
```

**Fix:** Point `SENSOR_DEV_GLOB` (in `climate-usb-sensor.service`) at the stable
`by-id` path of your probe, and confirm the baud rate with `SENSOR_BAUD`. See the
USB section of [HARDWARE.md](HARDWARE.md).

---

## `IntakeSensorDown` is firing

**Symptom:** The liveness alert is active even though nothing is on fire.

**Likely cause:** This is working as designed — the probe read failed, or no
fresh reading has arrived for over 10 minutes (timer stopped, device unplugged,
or the `by-id` path renumbered after a re-plug).

**Verify:**

```bash
journalctl -u climate-usb-sensor -n 30
systemctl list-timers climate-usb-sensor.timer
curl -s localhost:9100/metrics | grep -E 'climate_intake_(fetch_success|last_check)'
```

**Fix:** Re-seat the probe and confirm its `by-id` path still matches
`SENSOR_DEV_GLOB`; restart `climate-usb-sensor.timer`. While this alert fires,
`IntakeTempHigh` is blind — restore the sensor first.

---

## The forecast table is empty

**Symptom:** The "Daily maximum forecast" table shows nothing, while the
Prometheus-fed outdoor panels are fine.

**Likely cause:** The Infinity datasource plugin is not installed, Grafana was
not restarted after provisioning it, or the panel's baked-in coordinates return
no rows.

**Verify:** Check **Connections → Plugins** for `yesoreyeram-infinity-datasource`,
and test the API/transform directly (see [OPEN_METEO_GRAFANA.md](OPEN_METEO_GRAFANA.md)).

**Fix:** `grafana-cli plugins install yesoreyeram-infinity-datasource`, restart
Grafana, and set the panel's `url` coordinates to your location — the forecast
table's location lives in the dashboard JSON, **not** in `LATITUDE`/`LONGITUDE`.

---

## Outdoor "now" panel empty / `OutdoorFetchStale` firing

**Symptom:** The Prometheus-fed outdoor temperature is missing or stale.

**Likely cause:** The outdoor reader cannot reach Open-Meteo, `jq` is missing, or
`OPEN_METEO_MODEL` names an endpoint that does not exist.

**Verify:**

```bash
sudo systemctl start climate-outdoor-temp.service
journalctl -u climate-outdoor-temp -n 30
command -v jq curl
```

**Fix:** Confirm outbound HTTPS works from the host, install `jq`, and check
`LATITUDE`/`LONGITUDE`/`OPEN_METEO_MODEL` in `climate-outdoor-temp.service`. This
alert is `info` severity by design — a stale outdoor reference is cosmetic, not a
risk.

---

## No alert e-mails arrive

**Symptom:** Alerts fire in Prometheus/Alertmanager, but no mail is delivered.

**Likely cause:** Alertmanager is not wired up (the optional step 5), the SMTP
settings or password file are wrong, or Prometheus has no `alerting:` block
pointing at Alertmanager.

**Verify:**

```bash
amtool check-config /etc/alertmanager/alertmanager.yml
journalctl -u alertmanager -n 50
# Is Prometheus even sending alerts on?
curl -s localhost:9090/api/v1/alertmanagers
```

**Fix:** Follow [INSTALL.md](INSTALL.md) step 5 — deploy the template first, fill
in `smtp_*` and the recipient, write the password to the root-only
`smtp_password` file, and add the `alerting:` block to `prometheus.yml`.
