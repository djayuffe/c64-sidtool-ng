# Changelog

## Unreleased

* Fixed MIDI output to write unsigned bytes and an accurate track count.
* Reject incomplete SID payloads before conversion and correctly read empty
  metadata fields.
* Updated `mos6510` to 0.1.3, removing the obsolete V8 native dependency.
* Added MIDI serialization and parser edge-case regression coverage.

## 0.0.5
* Bumped to mos6510 version 0.1.2 which depends on a version of mini_racer that supports
  Ruby 3.1.

## 0.0.4
* Bumped to mos6510 version 0.1.1 which depends on a version of mini_racer that can compile
  and install on my machine.

## 0.0.3
* Add midi support.

## 0.0.2
* Process 15000 frames (10 minutes) instead of 1500 (half a minute) by default.
* Only release a synth once. This fixes various sound effects that would just end up with a
  permanently released synth. It will probably make "normal" tunes sound a bit crisper too.
* Ensuring that existing synth gets properly cut off before starting the next sync for a voice.
  This fixes songs like `Commando.sid` that sounded just weird before.

## 0.0.1
Just getting started... A lot of mess...
