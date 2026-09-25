require 'tempfile'

module Sidtool
  RSpec.describe Converter do
    def write_psid(path, init_address:, play_address:, program:, speed: 0, flags: 0, songs: 1, start_song: 1)
      header = +'PSID'
      header << [2, 0x7c, 0, init_address, play_address, songs, start_song].pack('n7')
      header << [speed].pack('N')
      header << ("\0" * (118 - header.bytesize))
      header << [flags].pack('n')
      header << ("\0" * (0x7c - header.bytesize))
      payload = [0x00, 0x10] + program
      File.binwrite(path, header + payload.pack('C*'))
    end

    it 'captures init writes at frame zero with PAL SID pitch' do
      Tempfile.create(['sidtool', '.sid']) do |file|
        file.close
        # $1000: set voice 1 to SID frequency $1000 and gate a triangle.
        init = [0xa9, 0x00, 0x8d, 0x00, 0xd4,
                0xa9, 0x10, 0x8d, 0x01, 0xd4,
                0xa9, 0x11, 0x8d, 0x04, 0xd4,
                0xa9, 0x00, 0x8d, 0x05, 0xd4,
                0xa9, 0xf0, 0x8d, 0x06, 0xd4, 0x60]
        play_address = 0x1000 + init.length
        write_psid(file.path, init_address: 0x1000, play_address: play_address,
                   program: init + [0x60])

        converter = Converter.new(FileReader.read(file.path), song: 1, frames: 1)
        synths = converter.convert
        synth = synths.first.first

        expect(synth.start_frame).to eq(0)
        expect(synth.tone).to eq(Sidtool.sid_frequency_to_midi(0x1000))
        expect(synth.controls).to eq([])
        expect(converter.sid_events.first(3)).to eq([
          { frame: 0, register: 0, value: 0 },
          { frame: 0, register: 1, value: 16 },
          { frame: 0, register: 4, value: 17 }
        ])
      end
    end

    it 'rejects CIA-timed songs instead of exporting PAL-timed output' do
      Tempfile.create(['sidtool', '.sid']) do |file|
        file.close
        write_psid(file.path, init_address: 0x1000, play_address: 0x1000,
                   program: [0x60], speed: 1)

        expect { Converter.new(FileReader.read(file.path), song: 1, frames: 1) }
          .to raise_error(ArgumentError, 'CIA-timed PSID songs are not supported')
      end
    end

    it 'uses the init-installed play vector once for a selected subtune' do
      Tempfile.create(['sidtool', '.sid']) do |file|
        file.close
        # Set $0314/$0315 only when A contains the second subtune index.
        init = [0xc9, 0x01, 0xd0, 0x0a,
                0xa9, 0x10, 0x8d, 0x14, 0x03,
                0xa9, 0x10, 0x8d, 0x15, 0x03, 0x60]
        write_psid(file.path, init_address: 0x1000, play_address: 0,
                   program: init + [0xea, 0x60], songs: 2, start_song: 2)

        sid_file = FileReader.read(file.path)
        expect(Converter.new(sid_file, song: 2, frames: 1).convert).to all(be_empty)
      end
    end

    it 'uses NTSC timing for NTSC-only songs' do
      Tempfile.create(['sidtool', '.sid']) do |file|
        file.close
        write_psid(file.path, init_address: 0x1000, play_address: 0x1000,
                   program: [0x60], flags: 0b1000)

        converter = Converter.new(FileReader.read(file.path), song: 1, frames: 1)
        expect(converter.frame_rate).to eq(60.0)
        expect(converter.convert).to all(be_empty)
      end
    end
  end
end
