# yangadeus

Play the eBGP control plane like a keyboard.

`yangadeus` maps the 25 keys of a MIDI keyboard onto the BGP neighbors of an
IOS XRd device. It keeps a **persistent NETCONF session** open to the router
(via the stratoweave `DeviceMgr`), and on each keypress fires a
`clear bgp <neighbor>` RPC — hard-resetting that neighbor's session live, on
stage.

```
  MIDI key  ─────►  yangadeus  ─────►  NETCONF RPC
   (C3)               │                clear-bgp-ip-addr { ip-addr 10.0.0.6 }
                      └── persistent session (DeviceMgr) ──► IOS XRd
```

## How it works

1. **Connect.** On startup it opens a NETCONF/SSH session to the XRd and holds
   it open (the `DeviceMgr` reconnects on its own if the link drops).
2. **Discover.** Once connected it does a `<get-config>` of the running
   datastore filtered to the BGP subtree
   (`Cisco-IOS-XR-um-router-bgp-cfg: router/bgp`), walks the reply and collects
   every configured neighbor address (it also understands the classic
   `Cisco-IOS-XR-ipv4-bgp-cfg` `neighbor-address` leaf). Each neighbor is
   labelled eBGP/iBGP by comparing its `remote-as` to the local `as`.
3. **Map.** eBGP peers (remote-as ≠ the local `as`) are sorted (IPv4
   numerically) and laid out on consecutive keys starting at `--base-note`; iBGP
   and unclassified peers are skipped unless `--all-neighbors` is given. The map
   is printed at startup.
4. **Play.** A key press (`note_on`) sends
   `Cisco-IOS-XR-ipv4-bgp-act:clear-bgp-ip-addr` for that neighbor — or the
   `-graceful` variant with `--graceful`.
5. **Light.** On a Launchkey Mini MK3, the 16 Session pads mirror activity: the
   pad for the pressed key goes **amber** while the clear is in flight, flashes
   **green** on `<ok/>`, or **red** on failure, then fades. See below.

The keyboard does **not** need to be plugged in at startup: the session comes up
and the map is built regardless, and yangadeus keeps looking for the MIDI source
until it appears.

### Pad LEDs (Launchkey Mini MK3)

Feedback is driven over the controller's **DAW port** (the keys arrive on the
MIDI port). At startup yangadeus opens that port, puts the pad grid into DAW /
Session mode, and blanks it. The 25 keys are spread proportionally across the 16
pads (`pos = key_index * 16 / neighbors`), top row then bottom row, left→right —
so several neighbors can share a pad: the pad tells you roughly *where* along the
keyboard a clear landed, not the exact peer. Colours come from Novation's
128-entry velocity palette (amber 9 / green 21 / red 5).

LED feedback is **best-effort**: if the DAW port is missing or held by another
app, yangadeus logs it and runs dark — the clears still fire. Disable it with
`--no-leds`. (This needs MIDI *output*, which the sibling `../midiact` checkout
now provides via its `Output` actor; a stock upstream `midi` has input only.)

## Build

```sh
make            # optimized build  -> out/bin/yangadeus
make debug      # faster to compile
```

The `make` targets build against the sibling **`../midiact`** checkout (via
`--dep midi=…`, set as `MIDI_DEP` in the Makefile) — it carries the `Output`
actor the pad LEDs need, which the pinned upstream `midi` lacks. Point it
elsewhere with `make MIDI_DEP="--dep midi=/abs/path"`, or clear it
(`make MIDI_DEP=`) to fall back to the `Build.act`-pinned upstream (no LEDs).
`stratoweave` and `yang` resolve from `Build.act`. To hack on a local
`acton-yang`: `make build-ldep`.

Cross-compile for the demo hosts with `make build-linux-x86_64` /
`build-linux-aarch64` / `build-macos-aarch64`.

## Run

```sh
out/bin/yangadeus --host 10.99.0.13 --port 1830 --username clab --password clab@123
```

| flag | default | meaning |
|------|---------|---------|
| `--host` | `localhost` | XRd NETCONF host |
| `--port` | `830` | XRd NETCONF port |
| `--username` / `--password` | `admin` / `admin` | NETCONF credentials |
| `--source` | `running` | datastore to read for discovery |
| `--midi-source` | *(first source)* | substring selecting the MIDI input |
| `--base-note` | `48` | MIDI note of the leftmost key (C3=48, middle C=60) |
| `--keys` | `25` | number of keys to map |
| `--peers` | *(discover)* | comma-separated neighbor list; skips NETCONF discovery |
| `--graceful` | off | graceful restart instead of a hard reset |
| `--all-neighbors` | off | map all neighbors incl. iBGP (default: eBGP only) |
| `--no-leds` | off | disable Launchkey pad LED feedback |
| `--verbose` | off | log the NETCONF/SSH stack |

`--peers` is handy for demoing the pads without a live router, e.g.
`out/bin/yangadeus --peers 10.0.0.6,10.0.0.10,10.0.0.14` maps three keys
immediately and lights their pads as you play.

### Calibrating the keyboard

Different 25-key controllers put their leftmost key at different MIDI notes. Any
key you press is printed with its note number even when unmapped, so:

1. Start yangadeus and look at the printed key map.
2. Press the lowest key; note the number it reports.
3. Restart with `--base-note <that number>` so the leftmost key lines up with
   the first neighbor.

Pick a specific controller with `--midi-source` (a case-insensitive substring of
the port name) if more than one MIDI source is present.
