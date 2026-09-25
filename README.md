# C64 SIDtool NG

Convert Commodore 64 PSID music into editable Ruby, Standard MIDI File, or a
frame-accurate JSON register trace.

This independent repository preserves the upstream MIT licence and attribution.
It is based on the `sidtool_ng` source from UbhaSecurity, itself derived from
the original Sidtool by Ole Friis Østergaard.

SID files contain Commodore 64 machine code. SIDtool NG runs the supported
player code through a MOS 6510 emulator and records the SID register writes it
produces. It is aimed at editing, analysis, and reuse—not waveform-accurate
audio playback.

## Supported Output Formats

| Format | Best for | Fidelity |
| --- | --- | --- |
| `ruby` | Sonic Pi or custom Ruby post-processing | Note and timing events |
| `midi` | DAW editing and general playback | Note and timing events |
| `json` | Analysis, custom emulators, and conversion tools | Ordered SID register writes |

The MIDI and Ruby exporters map SID waveforms to practical target instruments.
The JSON exporter retains every captured register write, its frame number, and
write order for the supported single-SID execution path.

## Limitations

The converter supports PSID versions 1–4 with one SID chip and PAL or NTSC vertical-blank
playback. It accepts both header-specified and embedded load addresses, retains
the selected subtune, and captures SID register changes at their original frame.
RSID files, CIA-timed PSID subtunes, and multi-SID files are rejected rather
than exported with incorrect timing.

MIDI and Ruby are note-event formats, not SID audio emulators. Pulse-width
modulation, filters, oscillator sync/ring modulation, samples, and exact ADSR
curves cannot be represented one-to-one. The exported timeline is exact for
the supported register-derived note, gate, waveform, and pitch events; the
target synth determines the final sound.

The conversion runs a specified number of frames (default is 15000 - this can be changed on the
command line). Ideally it should be able to run until the song finishes.

For remaining limitations, please use this repository's issue tracker.

## Quick start

```bash
bundle install
ruby examples/create_minimal_sid.rb
mkdir -p examples/output
bundle exec bin/sidtool --info examples/minimal-tone.sid
bundle exec bin/sidtool --format json --out examples/output/minimal-tone.json --frames 4 examples/minimal-tone.sid
```

The final command produces a JSON trace beginning with the SID frequency and
gate writes from the example's init routine. Generated example files are
ignored by Git.

## Usage

You can find lots of `.sid` files (and a super nice list of players for a wide range of platforms)
at the [High Voltage SID Collection](https://www.hvsc.c64.org) homepage.

Show information, like the author and number of songs in a file:

```bash
bundle exec bin/sidtool --info path/to/tune.sid
```

Convert the default song from a `.sid` file to a midi file:

```bash
bundle exec bin/sidtool --out tune.mid --format midi path/to/tune.sid
```

Convert the default song from a file to a Ruby list (`--format ruby` is the default):

```bash
bundle exec bin/sidtool --out tune.rb path/to/tune.sid
```

Export an exact ordered trace of the SID register writes captured during the
supported emulation path:

```bash
bundle exec bin/sidtool --out tune.json --format json --song 2 --frames 3000 path/to/tune.sid
```

`--song` is one-based and defaults to the tune's declared start song.
`--frames` controls how many vertical-blank play calls are captured; it
defaults to 15,000 frames. The JSON document contains `frame_rate`,
`sid_events`, and the note-oriented `voices` projection.

The Ruby output can then be used to play back the music, for example in Sonic Pi:

```ruby
load '<path to your output file from before>'

previous_frame = 0
::SYNTHS.each do |synth|
  current_frame = synth[0]
  frames_to_sleep = current_frame - previous_frame
  previous_frame = current_frame
  sleep frames_to_sleep/::FRAME_RATE if frames_to_sleep > 0
  
  in_thread do
    use_synth synth[2]
    played_synth = play synth[1], attack: synth[3], decay: synth[4], sustain: synth[5], release: synth[6]
    
    this_frame = current_frame
    controls = synth[7]
    controls.each do |c|
      sleep (c[0] - this_frame) / ::FRAME_RATE
      this_frame = c[0]
      control played_synth, note: c[1]
    end
  end
end
```

It's a bit hacky, I know. Part of the issue is that Sonic Pi has a limit on the size of the edit buffer,
so paste the above into the buffer and edit the first line so it loads the (probably rather large)
output file from `sidtool`.

## Development

After checking out the repo, run the following from the repository root:

```bash
bundle install
bundle exec rake spec
bundle exec bin/sidtool --help
```

The project uses `mos6510` 0.1.3 or later in the 0.1 line, which avoids the
obsolete V8 native extension required by earlier releases.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new
version, update the version number in `version.rb`, and then run `bundle exec rake release`,
which will create a git tag for the version, push git commits and tags, and push the `.gem` file
to [rubygems.org](https://rubygems.org).

## Contributing

For this repository, please use its GitHub issue tracker. Upstream attribution
and the MIT licence are retained in `LICENSE.txt`.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
