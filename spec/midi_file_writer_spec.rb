require 'tempfile'

module Sidtool
  RSpec.describe MidiFileWriter do
    # Trying to make frame specification in seconds a bit more readable...
    ONE_FRAME = 0.02
    let(:subject) { MidiFileWriter.new(synths) }

    describe '#build_track' do
      let(:track) { subject.build_track(synths) }

      TestSynth = Struct.new(:start_frame, :tone, :waveform, :attack, :decay, :sustain_length, :release, :controls)

      context 'with simple, sequential synths' do
        let(:synths) {
          [
            TestSynth[50, 75, :tri, ONE_FRAME, ONE_FRAME, ONE_FRAME, ONE_FRAME, []],
            TestSynth[100, 76, :tri, 2 * ONE_FRAME, 2 * ONE_FRAME, 2 * ONE_FRAME, 2 * ONE_FRAME, []]
          ]
        }

        it 'places commands sequentially' do
          expect(track).to eq([
            MidiFileWriter::DeltaTime[50], MidiFileWriter::NoteOn[0, 75],
            MidiFileWriter::DeltaTime[3], MidiFileWriter::NoteOff[0, 75],
            MidiFileWriter::DeltaTime[47], MidiFileWriter::NoteOn[0, 76],
            MidiFileWriter::DeltaTime[6], MidiFileWriter::NoteOff[0, 76]
          ])
        end
      end

      context 'with different waveforms' do
        let(:synths) {
          [
            TestSynth[50, 75, :tri, ONE_FRAME, ONE_FRAME, ONE_FRAME, ONE_FRAME, []],
            TestSynth[100, 76, :saw, ONE_FRAME, ONE_FRAME, ONE_FRAME, ONE_FRAME, []],
            TestSynth[150, 77, :pulse, ONE_FRAME, ONE_FRAME, ONE_FRAME, ONE_FRAME, []],
            TestSynth[200, 78, :noise, ONE_FRAME, ONE_FRAME, ONE_FRAME, ONE_FRAME, []]
          ]
        }

        it 'uses separate channels' do
          expect(track).to eq([
            MidiFileWriter::DeltaTime[50], MidiFileWriter::NoteOn[0, 75],
            MidiFileWriter::DeltaTime[3], MidiFileWriter::NoteOff[0, 75],
            MidiFileWriter::DeltaTime[47], MidiFileWriter::NoteOn[1, 76],
            MidiFileWriter::DeltaTime[3], MidiFileWriter::NoteOff[1, 76],
            MidiFileWriter::DeltaTime[47], MidiFileWriter::NoteOn[2, 77],
            MidiFileWriter::DeltaTime[3], MidiFileWriter::NoteOff[2, 77],
            MidiFileWriter::DeltaTime[47], MidiFileWriter::NoteOn[3, 78],
            MidiFileWriter::DeltaTime[3], MidiFileWriter::NoteOff[3, 78],
          ])
        end
      end

      context 'with controls' do
        let(:synths) {
          [
            TestSynth[50, 75, :tri, ONE_FRAME, ONE_FRAME, 20 * ONE_FRAME, ONE_FRAME, [[51, 76], [55, 80]]],
            TestSynth[100, 76, :tri, ONE_FRAME, ONE_FRAME, 10 * ONE_FRAME, ONE_FRAME, [[105, 70]]]
          ]
        }

        it 'converts them to sequential notes' do
          expect(track).to eq([
            # First synth - a total of 22 frames
            MidiFileWriter::DeltaTime[50], MidiFileWriter::NoteOn[0, 75],
            MidiFileWriter::DeltaTime[1], MidiFileWriter::NoteOff[0, 75],
            MidiFileWriter::DeltaTime[0], MidiFileWriter::NoteOn[0, 76],
            MidiFileWriter::DeltaTime[4], MidiFileWriter::NoteOff[0, 76],
            MidiFileWriter::DeltaTime[0], MidiFileWriter::NoteOn[0, 80],
            MidiFileWriter::DeltaTime[17], MidiFileWriter::NoteOff[0, 80],

            # Second synth - a total of 12 frames
            MidiFileWriter::DeltaTime[28], MidiFileWriter::NoteOn[0, 76],
            MidiFileWriter::DeltaTime[5], MidiFileWriter::NoteOff[0, 76],
            MidiFileWriter::DeltaTime[0], MidiFileWriter::NoteOn[0, 70],
            MidiFileWriter::DeltaTime[7], MidiFileWriter::NoteOff[0, 70]
          ])
        end
      end
    end

    describe 'DeltaTime#bytes' do
      it 'returns just the number when below 128' do
        expect(MidiFileWriter::DeltaTime[0].bytes).to eq([0])
        expect(MidiFileWriter::DeltaTime[1].bytes).to eq([1])

        expect(MidiFileWriter::DeltaTime[126].bytes).to eq([126])
        expect(MidiFileWriter::DeltaTime[127].bytes).to eq([127])
      end

      it 'splits up in two bytes when value is above 127' do
        expect(MidiFileWriter::DeltaTime[128].bytes).to eq([128 + 1, 0])
        expect(MidiFileWriter::DeltaTime[129].bytes).to eq([128 + 1, 1])
        expect(MidiFileWriter::DeltaTime[130].bytes).to eq([128 + 1, 2])
        expect(MidiFileWriter::DeltaTime[192].bytes).to eq([128 + 1, 64])
      end

      it 'rejects negative delta times' do
        expect { MidiFileWriter::DeltaTime[-1].bytes }
          .to raise_error(ArgumentError, 'MIDI delta time cannot be negative: -1')
      end

      it 'encodes a standard MIDI tempo event' do
        expect(MidiFileWriter::Tempo[9_600_000].bytes).to eq([0xFF, 0x51, 0x03, 0x92, 0x7C, 0x00])
      end
    end

    describe '#write_to' do
      it 'writes an unsigned MIDI byte stream with the correct track count' do
        Tempfile.create(['sidtool', '.mid']) do |file|
          file.close
          MidiFileWriter.new([[], []]).write_to(file.path)
          bytes = File.binread(file.path).bytes

          expect(bytes.first(4).pack('C*')).to eq('MThd')
          expect(bytes[8, 2]).to eq([0, 1])
          expect(bytes[10, 2]).to eq([0, 2])
          expect(bytes).to include(0xFF, 0x2F, 0x00)
        end
      end
    end
  end
end
