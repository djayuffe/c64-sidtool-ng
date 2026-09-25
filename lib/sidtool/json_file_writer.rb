require 'json'

module Sidtool
  # Writes a lossless ordered trace of SID register writes for the supported
  # single-SID PSID execution path. This is the fidelity-preserving alternative
  # to note-oriented MIDI and Ruby exports.
  class JsonFileWriter
    def initialize(synths_for_voices, frame_rate:, sid_events:)
      @synths_for_voices = synths_for_voices
      @frame_rate = frame_rate
      @sid_events = sid_events
    end

    def write_to(path)
      payload = {
        format: 'sidtool-register-trace-v1',
        frame_rate: @frame_rate,
        sid_events: @sid_events,
        voices: @synths_for_voices.map do |voice|
          voice.map do |synth|
            {
              start_frame: synth.start_frame,
              tone: synth.tone,
              waveform: synth.waveform.to_s,
              attack: synth.attack,
              decay: synth.decay,
              sustain_length: synth.sustain_length,
              release: synth.release,
              controls: synth.controls
            }
          end
        end
      }

      File.write(path, JSON.pretty_generate(payload) + "\n")
    end
  end
end
