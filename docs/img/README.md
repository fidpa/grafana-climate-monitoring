# Screenshots

The repository `README.md` embeds `dashboard.png` from this folder as its hero
image. To refresh it, replace that file in place (keep the name) — capture a new
screenshot of the shipped dashboard and re-run the leak check below first.

## Requirements for a publishable screenshot

The screenshot must show **the dashboard this repository ships** — i.e. the
English `grafana/dashboards/climate.json`, not an internal variant. Before
capturing, verify none of the following leak into the frame:

- No internal hostnames in panel titles or legends (the shipped dashboard uses
  the `$instance` variable and a neutral `room_sensor` label, so nothing
  host-specific should appear).
- No real location names (the outdoor panels read "Outdoor", not a city).
- No browser chrome showing an internal URL or the Grafana org name.

Recommended: capture in a light-neutral or the default dark theme at a wide
viewport so all five rows are legible, then downscale to ~1600 px wide to keep
the file small.
