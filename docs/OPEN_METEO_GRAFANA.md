# Outdoor temperature & forecast in Grafana

The dashboard shows outdoor temperature two ways, for two different reasons.

## Now: via Prometheus

`fetch-outdoor-temp.sh` polls Open-Meteo every 15 minutes and writes
`climate_outdoor_temp_celsius` into the textfile collector. Prometheus scrapes
it like any other metric, so the "outdoor now" stat and the second line on the
history graph are ordinary Prometheus panels. This is what you want for the
**past**: a recorded time series you can overlay against room temperature to
tell "the AC failed" apart from "it is 38 °C outside".

## Forecast: via the Infinity datasource

Prometheus can only store observed values — it has no concept of the future. To
show a **7-day forecast** the dashboard queries Open-Meteo *directly* from
Grafana using the [Infinity datasource](https://grafana.com/grafana/plugins/yesoreyeram-infinity-datasource/),
which turns an arbitrary REST/JSON response into table rows.

The forecast table calls:

```
https://api.open-meteo.com/v1/dwd-icon?latitude=52.52&longitude=13.405&daily=temperature_2m_max&forecast_days=8&timezone=auto
```

> **This URL is the only place the forecast location is set.** Unlike the
> `fetch-outdoor-temp.sh` reader (which honours the `LATITUDE`/`LONGITUDE` env
> vars), the table talks to Open-Meteo straight from Grafana, so its coordinates
> live here in the dashboard JSON. Change them here when you deploy, or the
> forecast will silently keep showing the default location.

### Gotcha: Open-Meteo returns *columnar* JSON

`daily` is **not** a list of objects. It is parallel arrays of equal length:

```json
{ "daily": { "time": ["2026-07-11", "2026-07-12"],
             "temperature_2m_max": [29.4, 31.1] } }
```

A naive column selector (`daily.time`) does not zip these into rows — you get
two cells containing comma-joined array strings instead of a proper table. The
fix is a JSONata `root_selector` that zips the arrays with `$map`:

```jsonata
$map(daily.time, function($t, $i) {
  { "Date": $t, "Max": daily.temperature_2m_max[$i] }
})
```

The dashboard's selector does exactly this, and additionally:

- **computes the weekday** with Zeller's congruence (pure arithmetic — Grafana's
  JSONata port has no locale-aware date formatting), and
- **filters trailing nulls** with `$rows[Max != null]`, because DWD ICON only
  computes ~7.5 days: `forecast_days=8` yields 7 or 8 real rows depending on the
  model run, and the surplus days come back `null`.

### Choosing a model and horizon

- `dwd-icon` is a good Central-European choice. Use `forecast` for the global
  best-match model, or any other Open-Meteo model endpoint.
- ICON's usable horizon is about a week; do not raise `forecast_days` expecting
  more — you will only collect `null`s past the model limit.

### Verifying the selector without Grafana

You can test the transform against the live API before deploying:

```bash
curl -s 'https://api.open-meteo.com/v1/dwd-icon?latitude=52.52&longitude=13.405&daily=temperature_2m_max&forecast_days=8&timezone=auto' \
  | npx jsonata -  '$map(daily.time, function($t,$i){ {"Date":$t,"Max":daily.temperature_2m_max[$i]} })'
```

Open-Meteo is free for non-commercial use and needs no API key.
