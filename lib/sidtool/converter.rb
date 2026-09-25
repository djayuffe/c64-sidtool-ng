require 'mos6510'

module Sidtool
  # Runs one supported PSID subtune and captures the SID register timeline.
  class Converter
    attr_reader :sid_file, :song, :frames

    def initialize(sid_file, song:, frames:)
      @sid_file = sid_file
      @song = song
      @frames = frames

      raise ArgumentError, 'Song must be at least 1' if song < 1
      raise ArgumentError, "File only has #{sid_file.songs} songs" if song > sid_file.songs
      raise ArgumentError, 'Frame count must not be negative' if frames.negative?
      raise ArgumentError, 'CIA-timed PSID songs are not supported' if sid_file.cia_timed?(song)
      raise ArgumentError, 'Multi-SID PSID songs are not supported' if sid_file.multi_sid?
      raise ArgumentError, 'NTSC-only PSID songs are not supported' if sid_file.ntsc_only?
    end

    def convert
      STATE.reset!
      sid = Sid.new
      cpu = Mos6510::Cpu.new(sid: sid)
      cpu.load(sid_file.data, from: sid_file.load_address)
      cpu.start

      # A = zero-based subtune index, as required by the PSID init routine.
      cpu.jsr(sid_file.init_address, song - 1)
      sid.finish_frame

      play_address = sid_file.play_address
      if play_address.zero?
        play_address = (cpu.peek(0x0315) << 8) + cpu.peek(0x0314)
        raise ArgumentError, 'PSID init routine did not provide a play address' if play_address.zero?
      end

      frames.times do
        cpu.jsr(play_address)
        sid.finish_frame
        STATE.advance!
      end

      sid.stop!
      sid.synths_for_voices
    end
  end
end
