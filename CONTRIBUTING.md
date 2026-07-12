# Contributing

Thanks for your interest in improving this project. It is small on purpose —
contributions that keep it small and sharp are the most welcome.

## Ground rules

- Keep changes focused. One idea per pull request.
- Match the surrounding style. The shell scripts favour explicit error checks
  over `set -e`, atomic file writes, and soft-fail behaviour.
- No real IPs, hostnames, coordinates, or credentials in any file. Use RFC 5737
  addresses (`192.0.2.0/24`) and `example.com` in documentation.

## Before you open a pull request

Run the same checks CI runs:

```bash
# Shell
find scripts -name '*.sh' -print0 | xargs -0 shellcheck --severity=warning
find scripts -name '*.sh' -print0 | xargs -0 -I {} bash -n {}

# YAML
yamllint prometheus grafana alertmanager .github

# Dashboard JSON
python3 -c "import json; json.load(open('grafana/dashboards/climate.json'))"
```

If you have Prometheus installed locally, validate the alert rules too:

```bash
promtool check rules prometheus/alerts/climate-alerts.yml
```

If you touch `alertmanager/`, CI validates the config **and** the e-mail template
with `amtool check-config` (via the `prom/alertmanager` container). You can run
the same check locally with that image — see `.github/workflows/lint.yml`.

## Reporting issues

Open a GitHub issue with your Grafana / Prometheus / node_exporter versions,
the sensor model you use, and — for a dashboard problem — a screenshot and the
panel's query.
