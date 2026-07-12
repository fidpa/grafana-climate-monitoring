# Hardware

You need two temperature sources. Both are optional on their own, but together
they give you the fast **and** the broad signal.

## 1. Room air — a hwmon sensor

Most server and desktop motherboards already expose a temperature sensor that
`node_exporter` reads through Linux `hwmon`, with **no extra hardware**. This is
your slow, broad "how warm is the room" signal. For a genuine room-air reading
you can add a wire thermistor — see the subsection below.

Find yours:

```bash
# List every hwmon temperature and its labels
for f in /sys/class/hwmon/hwmon*/temp*_input; do
  chip=$(cat "$(dirname "$f")/name")
  echo "$chip  $(basename "$f")  $(($(cat "$f")/1000))°C"
done

# Or, straight from what node_exporter actually exports:
curl -s localhost:9100/metrics | grep node_hwmon_temp_celsius
```

Pick the chip/sensor that tracks ambient/case air (often a motherboard or an
external-sensor header, not the CPU core). Then set the dashboard's
`room_sensor` textbox variable and the `RoomTempHigh` alert matcher to it, e.g.:

```
chip="nct6798-isa-0290",sensor="temp2"
```

### A wire thermistor at the mainboard T_SENSOR header (recommended)

On-board hwmon channels read the *board*, not the *air* — a VRM, chipset or
package temperature drifts with load, not with the room. Many motherboards
expose a dedicated header for an external thermistor precisely to fix this:
labelled `T_SENSOR` / `T_SEN`, it accepts a 2-pin 10 kΩ NTC probe and reads it
out through `hwmon` like any other channel (on ASUS boards via the
`asus-ec-sensors` driver, typically as `tempN` with a `T_Sensor` label).

Why it beats an on-die reading: you plug a 10 kΩ NTC wire thermistor into the
header, route the short lead out through a case opening, and let the sensor head
hang **in free room air**. The result is a real case-intake/room-air value
instead of a component temperature — the same `node_hwmon_temp_celsius` metric,
just measuring the right thing.

```bash
# Once the thermistor is plugged in and the driver is loaded, it appears as a
# normal hwmon channel — find it exactly as above:
sensors | grep -iA3 'asusec\|ec_sensors'
curl -s localhost:9100/metrics | grep -i 't_sensor\|asus_ec'
```

Then point the dashboard's `room_sensor` variable and the `RoomTempHigh` matcher
at that channel, e.g. `chip="platform_asus_ec_sensors",sensor="temp4"`.

> **Note — the open-header pseudo value:** with *nothing* plugged in, an ASUS
> controller reports a fixed junk reading (around `-60 °C`) because it
> extrapolates past the voltage-divider limit. That is the "no probe connected"
> value, not a fault — plugging in a real 10 kΩ NTC turns the channel into a
> usable metric.

## 2. AC cold-air stream — a USB serial temperature probe

This is the point of the whole project: place a probe **in the cold-air stream**
of the air conditioner. When cooling fails, that stream warms within seconds,
long before the room average moves. This is your fast cooling-failure signal.

Any USB serial thermometer that self-streams ASCII works. IP67 probes built on
a **CP2102N**, **CH340**, or **FTDI** USB-UART bridge are widely available.
`read-usb-temp-sensor.sh` assumes the device streams lines of the form
`<float>\r\n` at 9600 baud, 8N1 — adjust `SENSOR_BAUD` and the parser if yours
differs.

Find the stable device path (it survives re-plugging and `ttyUSB` renumbering):

```bash
ls -l /dev/serial/by-id/
# e.g. usb-Silicon_Labs_CP2102N_USB_to_UART_...-if00-port0

# Watch the raw stream (Ctrl-C to stop):
stty -F /dev/serial/by-id/*-if00-port0 9600 raw -echo
cat /dev/serial/by-id/*-if00-port0
```

If you have several USB-serial adapters, narrow the reader's glob so it picks
the right one:

```
SENSOR_DEV_GLOB=/dev/serial/by-id/*CP2102N*-if00-port0
```

## Cabling

The probe needs to reach the AC outlet, which is usually several metres from the
server. A **powered/active USB extension** (with a repeater chip) carries USB
reliably past the ~5 m passive limit. Plug the probe into whichever host already
runs `node_exporter` near the rack — it does not have to be the monitored server.
