require 'sidtool/version'

module Sidtool
  require 'sidtool/file_reader'
  require 'sidtool/ruby_file_writer'
  require 'sidtool/midi_file_writer'
  require 'sidtool/synth'
  require 'sidtool/voice'
  require 'sidtool/sid'
  require 'sidtool/state'
  require 'sidtool/converter'

  # PAL properties
  FRAMES_PER_SECOND = 50.0
  CLOCK_FREQUENCY = 985248.0

  STATE = State.new

  # Convert a 16-bit SID frequency register value to PAL Hertz and MIDI note.
  # SID frequency is a phase increment, not a Hertz value.
  def self.sid_frequency_to_hz(value)
    value * (CLOCK_FREQUENCY / 16_777_216.0)
  end

  def self.sid_frequency_to_midi(value)
    raise ArgumentError, 'SID frequency must be positive' unless value.positive?

    (69 + (12 * Math.log(sid_frequency_to_hz(value) / 440.0) / Math.log(2))).round
  end
end
