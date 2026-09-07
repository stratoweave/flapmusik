# yangadeus and kapellmeister

Play the eBGP control plane from a MIDI keyboard. Hear the result.

This directory is one Acton project, and it builds two programs:

- **yangadeus** maps the 25 keys of a MIDI keyboard onto the BGP neighbors of
  an IOS XRd device. Each key press sends a `clear bgp <neighbor>` RPC. The RPC
  resets the session to that neighbor.
- **kapellmeister** subscribes to the eBGP session state that flapmusik
  publishes. It holds one voice on a synthesizer for each session that is down.

```
  keys  ───►  yangadeus      ───►  clear-bgp RPC        ───►  IOS XRd    :1830
  synth ◄───  kapellmeister  ◄───  YANG-push on-change  ◄───  flapmusik  :2830
```

The two programs form a loop. A key clears a session, and the network answers
with sound. Neither program needs the other. Each one connects to its own
server.

`acton build` compiles every module with a `main` actor into its own binary.
One build writes both `out/bin/yangadeus` and `out/bin/kapellmeister`.

## Build

```sh
make            # optimized build  -> out/bin/yangadeus, out/bin/kapellmeister
make debug      # faster to compile
```

`make build` reads every dependency from `Build.act`.

`make build-ldep` replaces `yang` and `stratoweave` with local sibling
checkouts. Use it for work on those libraries. `Build.act` pins `yang` to the
revision that the pinned `stratoweave` compiles against. That target therefore
works only while the local checkouts agree with each other.

Cross-compile for the demo hosts with `make build-linux-x86_64`,
`make build-linux-aarch64` or `make build-macos-aarch64`.

## yangadeus — the keyboard

`yangadeus` holds a persistent NETCONF session open to the router, through the
stratoweave `DeviceMgr`. It sends one clear-BGP RPC for each key press.

```
  MIDI key  ─────►  yangadeus  ─────►  NETCONF RPC
   (C3)               │                clear-bgp-ip-addr { ip-addr 10.0.0.6 }
                      └── persistent session (DeviceMgr) ──► IOS XRd
```

You do not have to connect the keyboard before you start yangadeus. The
NETCONF session opens, and yangadeus builds the neighbor map. It then searches
for the MIDI source every 2 seconds.

That search never stops. Unplugging the controller destroys its ALSA sequencer
client, and replugging it creates a new one, so the endpoint yangadeus opened
goes stale and silent, and the connection to the DAW port goes with it. Nothing
reports that. yangadeus therefore keeps polling, notices the endpoint it opened
has left the list, and attaches to the new one — which also re-enters DAW mode
and blanks the pads. Pull the USB cable mid-demo and it comes back on its own.

### How it works

1. **Connect.** yangadeus opens a NETCONF/SSH session to the XRd and holds it
   open. The `DeviceMgr` connects again if the link drops.
2. **Discover.** yangadeus sends a `<get-config>` of the running datastore. A
   subtree filter narrows the request to the BGP tree
   (`Cisco-IOS-XR-um-router-bgp-cfg: router/bgp`). yangadeus reads the reply
   and collects every neighbor address. It also accepts the
   `neighbor-address` leaf of the classic `Cisco-IOS-XR-ipv4-bgp-cfg` model.
3. **Classify.** yangadeus compares the `remote-as` of each neighbor to the
   local `as`. A different AS number makes the neighbor an eBGP peer. An equal
   AS number makes it an iBGP peer.
4. **Map.** yangadeus sorts the eBGP peers by IPv4 address, in numeric order.
   It puts them on consecutive keys from `--base-note` up. It skips the iBGP
   peers, and also each peer with no `remote-as`. `--all-neighbors` keeps them
   all. yangadeus prints the map at startup.
5. **Play.** A key press (`note_on`) sends
   `Cisco-IOS-XR-ipv4-bgp-act:clear-bgp-ip-addr` for the neighbor on that key.
   `--graceful` selects the `-graceful` variant, which asks for a graceful
   restart.
6. **Light.** The 16 Session pads of a Launchkey Mini MK3 show each clear. See
   "Pad LEDs" below.

yangadeus makes no sound. kapellmeister plays the result, in its own process.

### Pad LEDs (Launchkey Mini MK3)

yangadeus sends the pad colours to the **DAW port** of the controller. The keys
arrive on the MIDI port. At startup yangadeus opens the DAW port. It puts the
pad grid into DAW/Session mode. It then sets all 16 pads to off.

Each pad then shows the state of a clear:

- **Amber** while yangadeus waits for the reply.
- **Green** for an `<ok/>` reply. The pad is off again after 0.5 seconds.
- **Red** for a failure. The pad is off again after 0.9 seconds.

yangadeus spreads the 25 keys across the 16 pads
(`pos = key_index * 16 / neighbors`). The order is the top row first, then the
bottom row, from left to right. Several neighbors can therefore share one pad.
A pad shows the approximate position of a clear along the keyboard. It does not
identify the exact peer. The colours are velocity values from the 128-entry
palette of Novation: amber 9, green 21 and red 5.

The pad LEDs are optional. If the DAW port is absent, or another program holds
it, yangadeus prints a message and continues without the pads. It still sends
the clear RPCs. `--no-leds` disables the pads. The pads need MIDI output, from
the `Output` actor in `midiact`.

### Run yangadeus

```sh
out/bin/yangadeus --host 10.99.0.13 --port 1830 --username clab --password clab@123
```

| flag | default | meaning |
|------|---------|---------|
| `--host` | `localhost` | XRd NETCONF host |
| `--port` | `1830` | XRd NETCONF port |
| `--username` / `--password` | `clab` / `clab@123` | NETCONF credentials |
| `--source` | `running` | datastore to read for discovery |
| `--midi-source` | *(first source)* | substring that selects the MIDI input |
| `--base-note` | `48` | MIDI note of the leftmost key (C3=48, middle C=60) |
| `--keys` | `25` | number of keys to map |
| `--peers` | *(discover)* | comma-separated neighbor list, in place of NETCONF discovery |
| `--graceful` | off | ask for a graceful restart, and not a hard reset |
| `--all-neighbors` | off | map all neighbors, including iBGP (default: eBGP only) |
| `--no-leds` | off | disable the Launchkey pad LEDs |
| `--verbose` | off | log the NETCONF/SSH stack |

`make start` runs the same command with the lab defaults. `HOST`, `PORT`,
`USERNAME`, `PASSWORD` and `ARGS` replace them. Easier still, each lab under
[`../test/`](../test/) has a `make play` recipe that already knows its own
router and port.

Use `--peers` to show the pads without a live router. For example,
`out/bin/yangadeus --peers 10.0.0.6,10.0.0.10,10.0.0.14` maps three keys
immediately, and the pads light as you play.

### Calibrate the keyboard

Different 25-key controllers put the leftmost key at different MIDI notes.
yangadeus prints the note number of every key you press, also for a key with no
neighbor. To align the keyboard:

1. Start yangadeus. Read the key map that it prints.
2. Press the lowest key. Read the note number in the output.
3. Start yangadeus again with `--base-note <that number>`. The leftmost key now
   holds the first neighbor.

Use `--midi-source` to select one controller out of several. The value is a
substring of the port name, and the match ignores case.

## kapellmeister — the sound

`kapellmeister` subscribes on-change (RFC 8641 YANG-push) to the northbound
NETCONF server of flapmusik. It plays
`/netinfra/ebgp-peer/state/session-state` as notes on a synthesizer.

```
  synth  ◄─────  kapellmeister  ◄─────  YANG-push on-change
  (a voice          │                   /netinfra/ebgp-peer/state/session-state
   per break)       └── NETCONF subscription ──── flapmusik northbound  :2830
```

This is the same feed that `./monitor` in the repository root shows as a table.

### What you hear

- **One held voice for each session that is down.** A fabric with no broken
  session is silent. A clear starts the voice of that peer. The voice stops
  when the session is established again. Each additional broken session adds
  one more voice.
- **A timpani stroke on the tonic** at the moment a session leaves
  `established`.
- **One pizzicato note for each step of the FSM** on the way back. `connect`,
  `active`, `open-sent` and `open-confirm` each sound one note of a rising G
  major arpeggio. A recovery therefore plays the figure that opens the
  serenade. The peer is silent after that.
- **The opening of the serenade** when the fabric is whole. This is the rising
  G major arpeggio, G D G D G B D G, and it resolves an octave up. It runs 2.5
  seconds, so it sounds like a flourish and not like an interruption.
  `--no-fanfare` disables it.

kapellmeister plays the serenade opening in two cases. The first case is
startup, when every session is already up. The second case is the recovery of
the last session that was down. The repair of the fabric therefore completes
the tune.

The startup case needs two things: the state baseline and the synthesizer.
They arrive in either order. kapellmeister plays the opening at the first
moment it holds both, and it makes this decision one time only. A snapshot is a
baseline and not an event, so a snapshot sets the chord and makes no sound.
kapellmeister therefore stays silent when the state feed connects again.

### The parts

The parts follow *Eine kleine Nachtmusik*, a string serenade in **G major**.
The cello holds the session voices. Pizzicato strings play the climb. The
timpani plays the stroke. The violin plays the serenade opening. A serenade
scores the sustained bed for the lower strings and gives the melody to the
violins. These samples can hold those parts.

The "String Ensemble" sample of TimGM6mb flutters. Its amplitude moves between
31% and 39% through a held note, at every pitch, and you hear this as a loop.
The cello holds to between 1% and 4%.

The voices use a **G major pentatonic** layout from G2 up. A pentatonic layout
has no semitones. All 25 voices can therefore sound together and still agree.
The result stays consonant for any number of broken sessions.

kapellmeister mixes the two layers with MIDI channel volume (CC 7), and not
with velocity. It sets the volume one time, when it opens the synthesizer. A
held voice must stay far below the ceiling, because 25 voices can sound at
once. A transition is a single event, and it must sound above the held voices.
Each patch has its own loudness, so the levels follow the patch and not a rule.

These are the measured peaks with TimGM6mb at `-g 1.5`:

- one voice: 1307
- all 25 voices: 15612
- a timpani stroke: 24345
- all 25 voices with a stroke: 80% of full scale

The programs and the levels are constants at the top of
`src/kapellmeister.act`.

A larger soundfont would improve all of this, because the flutter comes from
short samples. `fluidr3mono-gm-soundfont` (23 MB) holds the FluidR3 samples in
mono, and it is the best trade between size and quality here.
`fluid-soundfont-gm` is the full version, at 145 MB. You must measure the
levels again for both, because patch loudness changes with the soundfont.

### Which peer gets which voice

A peer is the netinfra list key: `[router, peer-address]`. The sync-on-start
snapshot contains the whole peer list. kapellmeister sorts the list by router,
and then by IPv4 address in numeric order. The lowest address gets the lowest
voice. yangadeus puts the same fabric on the keys in the same order.

A peer that first appears after the baseline takes the next free voice. A peer
then keeps that voice for as long as the process runs. A new peer must not move
the notes that already sound.

The layout puts five voices in each octave, from G2 up, so 25 voices reach E7.
Above E7 a cello sample no longer sounds like a cello. kapellmeister therefore
tracks a 26th peer, but it holds no voice for it.

The pitch comes from the layout of kapellmeister. It does not come from the key
that cleared the session. kapellmeister cannot see that key, and it does not
need it. The two ends of a session have different addresses. flapmusik keys a
peer by the address that its own router sees (`10.123.1.2`). yangadeus maps the
neighbors of the router that it drives (`10.123.1.1`). A join through
`ebgp-peer/local-address` relates the two views. The sonification did that join
while it was a part of yangadeus. The two programs are now separate, and
neither one needs it.

### The synthesizer

`midi`/midiact carries MIDI messages, and it does not make audio.
kapellmeister therefore plays to a **software synthesizer that appears as a
MIDI destination**. Any synthesizer on the ALSA sequencer bus works.

Provision a host with [`setup-audio`](setup-audio):

```sh
./setup-audio
```

It installs FluidSynth and the 6 MB TimGM6mb soundfont, puts you in the `audio`
group, grants that group realtime priority, opens the output to unity, and
installs [`kapellmeister-synth.service`](kapellmeister-synth.service) as a
systemd *user* unit. `loginctl enable-linger` then starts that unit on boot,
with nobody logged in. Re-run the script freely. It changes only what is not
already set.

Reboot after the first run. A user that was just added to a group does not hold
it until its systemd user manager restarts, and with linger on that manager
outlives a logout.

```sh
systemctl --user status kapellmeister-synth   # active (running)
./check-audio                                 # 1 process, 1 MIDI port(s)
```

The unit runs one command:

```sh
fluidsynth -is -a pipewire -m alsa_seq -g 1.5 -r 48000 -z 512 \
    /usr/share/sounds/sf2/TimGM6mb.sf2
```

`-s` is not optional. It runs FluidSynth as a server. `-i` disables the
interactive shell. Without `-s`, FluidSynth then has no work left. It prints
its banner and exits after approximately 130 ms.

`-g` sets the master gain. TimGM6mb is a quiet soundfont. The default of 0.2
and the common value of 0.8 are both too quiet here. 1.5 reaches 80% of full
scale at the loudest moment, which is 25 voices with a drum accent and a climb
note. 2.5 clips that moment.

That 80% is all the headroom there is, so **loudness that is missing is missing
on the output and not in the unit.** `setup-audio` opens the default sink to
unity for that reason:

```sh
wpctl set-volume @DEFAULT_AUDIO_SINK@ 100%
```

Set the level with `wpctl` and not with `amixer`. PipeWire owns the codec's
`Master` control and drives it from the active route's volume, so a level
written with `amixer` is overwritten at the next route change, and `alsactl
store` cannot hold it either. `wpctl` writes the route volume, and WirePlumber
saves that to `~/.local/state/wireplumber/default-routes`, which is what makes
it outlive a reboot.

`wpctl`'s percentage is a cubic taper, so a sink sitting at 40% is 0.064 in
linear terms. That is a 24 dB cut, and no `-g` wins it back. Trim from unity
with the same command when the amplifier has no knob of its own.

The volume is saved **per route**, and the headphone jack and the speakers each
keep their own. Run `setup-audio` with the demo's cable already in the jack, or
the level lands on the route nobody is listening to. `./check-audio` prints the
sink that is default and the level it is at.

`-a pipewire` plays to PipeWire directly, because PipeWire is the audio server.
The `alsa` driver reaches the same server through the pipewire-alsa plugin, one
hop later, and prints `warning: Requested a period size of 64, got 940 instead`
on the way. `-r 48000` is PipeWire's own rate, so nothing resamples, and
`-z 512` halves its default 1024-frame quantum.

kapellmeister selects the instruments. It sends one program change for each
channel that it uses, when it opens the synthesizer. MIDI has no message for
the master gain, so `-g` sets it.

kapellmeister finds the synthesizer itself. It takes the first destination with
`fluid` or `synth` in the name, so FluidSynth needs no flag.
`--synth <substring>` selects a different destination.

Nothing has to start first. kapellmeister searches for the synthesizer every 2
seconds, and for the state feed every 5 seconds, until each one appears. Run
`./check-audio` when you hear nothing. It reports the state of the audio path.

### What bites on Ubuntu 26.04

Five assumptions in the FluidSynth documentation no longer hold. `setup-audio`
and the unit handle all of them, and each one is silent when it is wrong.

- **The `audio` group is what makes sound work unattended.** logind grants the
  `/dev/snd` ACL to the session that is active on the seat. A rig whose greeter
  holds the seat, or that nobody logs into, therefore has no audio at all:
  PipeWire enumerates no devices and offers a single `Dummy Output` sink, and
  `aplay -l` reports no soundcards while the card sits there in
  `/proc/asound/cards`. Group membership does not depend on who is at the
  console.
- **The packaged `fluidsynth.service` cannot start.** It hardens itself with
  options a user unit can apply only inside a user namespace, and Ubuntu ships
  `kernel.apparmor_restrict_unprivileged_userns=1`, so every process it spawns
  dies with `218/CAPABILITIES`. It is enabled in *global* scope, so
  `setup-audio` masks it. Disabling it per-user is not enough.
- **`fluidsynth` no longer depends on `timgm6mb-soundfont`.** Ask for the
  soundfont by name. `fluidr3mono-gm-soundfont` (23 MB) and
  `fluid-soundfont-gm` (145 MB) sound better, but they outrank TimGM6mb in the
  `default-GM` alternatives the moment they are installed, and patch loudness
  changes with the soundfont. The unit names its soundfont by full path for
  that reason, and `-g 1.5` has to be measured again before either is used.
- **FluidSynth stays up when the sequencer is missing.** It logs `Error opening
  ALSA sequencer`, says no MIDI input will be available, and keeps running as a
  healthy-looking audio-only server that kapellmeister never finds. The unit
  tests `/dev/snd/seq` first, so the failure is visible and `Restart=` retries
  until the device is there.
- **`/usr/bin/test` is uutils, not GNU.** Its `-r` and `-w` ignore
  supplementary groups, so it calls `/dev/snd/seq` unwritable for a user who
  reaches it through `audio`. The unit runs that test through `/bin/sh`, whose
  builtin uses `access(2)` and gets both the yes and the no right.

### Run kapellmeister

```sh
out/bin/kapellmeister --host 127.0.0.1 --port 2830 --username admin --password admin
```

`make listen` runs that with the defaults; the labs under
[`../test/`](../test/) have their own `make listen` pinned to their northbound
port.

| flag | default | meaning |
|------|---------|---------|
| `--host` | `127.0.0.1` | NETCONF host that publishes the session state (flapmusik northbound) |
| `--port` | `2830` | NETCONF port of the session-state feed |
| `--username` / `--password` | `admin` / `admin` | credentials for that feed |
| `--synth` | *(fluid/synth)* | substring that selects the MIDI destination to play on |
| `--no-fanfare` | off | do not play the Nachtmusik opening when every session recovers |
| `--verbose` | off | log the NETCONF/SSH stack |

The defaults are the flapmusik server in `test/ietf-hackathon-xrd`. This server
is not the router. yangadeus connects to the XRd on port 1830, and
kapellmeister connects to flapmusik on port 2830.

`make listen` runs the command above with those defaults. `STATE_HOST`,
`STATE_PORT`, `STATE_USERNAME`, `STATE_PASSWORD` and `ARGS` replace them.
