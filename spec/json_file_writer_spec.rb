require 'json'
require 'tempfile'

module Sidtool
  RSpec.describe JsonFileWriter do
    SynthRecord = Struct.new(:start_frame, :tone, :waveform, :attack, :decay,
                             :sustain_length, :release, :controls)

    it 'writes an ordered, frame-accurate SID register trace' do
      synth = SynthRecord.new(0, 60, :tri, 0.01, 0.02, 0.5, 0.1, [[2, 62]])
      events = [{ frame: 0, register: 0, value: 0 }, { frame: 2, register: 4, value: 17 }]

      Tempfile.create(['sidtool', '.json']) do |file|
        JsonFileWriter.new([[synth]], frame_rate: 50.0, sid_events: events).write_to(file.path)
        trace = JSON.parse(File.read(file.path))

        expect(trace['format']).to eq('sidtool-register-trace-v1')
        expect(trace['frame_rate']).to eq(50.0)
        expect(trace['sid_events']).to eq([
          { 'frame' => 0, 'register' => 0, 'value' => 0 },
          { 'frame' => 2, 'register' => 4, 'value' => 17 }
        ])
        expect(trace['voices'][0][0]['waveform']).to eq('tri')
      end
    end
  end
end
