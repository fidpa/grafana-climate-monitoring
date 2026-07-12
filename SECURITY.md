# Security Policy

## Scope

This project ships shell scripts, systemd units, Prometheus alert rules, and a
Grafana dashboard. It reads a local serial device and a public weather API and
writes plain-text metric files. It handles no credentials and opens no network
listeners of its own.

## Reporting a vulnerability

Please report security issues privately via GitHub's
[private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
rather than opening a public issue. You can expect an initial response within a
few days.

## Deployment notes

- The USB sensor reader runs as root only because serial devices and the
  textfile collector directory are typically root-owned. If you can grant your
  node_exporter user access to the device and the directory, run it unprivileged.
- Grafana, Prometheus, and node_exporter are **not** exposed by anything in this
  repository. Do not bind them to public interfaces; keep them behind your LAN,
  a VPN, or an authenticating reverse proxy.
- The Open-Meteo request is anonymous and carries only coordinates. Treat those
  coordinates as the approximate location they reveal.
