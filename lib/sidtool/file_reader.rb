module Sidtool
  class FileReader
    attr_reader :format, :version, :load_address, :init_address, :play_address, :songs, :start_song
    attr_reader :name, :author, :released
    attr_reader :data, :speed, :flags, :second_sid_address, :third_sid_address

    def self.read(path)
      contents = File.open(path, 'rb', encoding: 'ascii-8bit') { |file| file.read }

      minimum_file_size = 0x76

      raise "File is too small - it should be at least #{minimum_file_size} bytes. The file may be corrupt." unless contents.length >= minimum_file_size

      format = contents[0..3]
      raise "Unknown file format: #{format}. Only PSID is supported." unless format == 'PSID'

      version = read_word(contents[4..5])
      raise "Invalid version number: #{version}. Only versions 1, 2, 3, and 4 are supported." unless version >= 1 && version <= 4

      data_offset = read_word(contents[6..7])
      minimum_data_offset = version == 1 ? 0x76 : 0x7C
      unless data_offset >= minimum_data_offset && data_offset <= contents.length
        raise "Invalid data offset: #{data_offset}. It must be between #{minimum_data_offset} and the file size. The file may be corrupt."
      end

      header_load_address = read_word(contents[8..9])

      init_address = read_word(contents[10..11])
      play_address = read_word(contents[12..13])
      songs = read_word(contents[14..15])
      start_song = read_word(contents[16..17])
      speed = read_long_word(contents[18..21])
      raise 'PSID must contain at least one song.' if songs.zero?
      raise "Invalid start song: #{start_song}." unless start_song.between?(1, songs)

      name = read_null_terminated_string(contents[22..53])
      author = read_null_terminated_string(contents[54..85])
      released = read_null_terminated_string(contents[86..117])

      payload = read_bytes(contents[data_offset..-1])
      if header_load_address.zero?
        raise 'SID data is missing the two-byte load address.' if payload.length < 2

        load_address = payload[0] + (payload[1] << 8)
        data = payload.drop(2)
      else
        load_address = header_load_address
        data = payload
      end
      raise 'SID data is empty.' if data.empty?
      raise 'SID data does not fit in C64 memory.' if data.length > 0x10000 - load_address

      init_address = load_address if init_address.zero?
      flags = version == 1 ? 0 : read_word(contents[118..119])
      second_sid_address = version < 3 ? 0 : contents[122]
      third_sid_address = version < 4 ? 0 : contents[123]

      return self.new(format: format, version: version, load_address: load_address, init_address: init_address, play_address: play_address,
                      songs: songs, start_song: start_song, name: name, author: author, released: released,
                      data: data, speed: speed, flags: flags, second_sid_address: second_sid_address,
                      third_sid_address: third_sid_address)
    end

    def initialize(format:, version:, load_address:, init_address:, play_address:, songs:, start_song:, name:, author:, released:, data:, speed:, flags:, second_sid_address:, third_sid_address:)
      @format = format
      @version = version
      @load_address = load_address
      @init_address = init_address
      @play_address = play_address
      @songs = songs
      @start_song = start_song
      @name = name
      @author = author
      @released = released
      @data = data
      @speed = speed
      @flags = flags
      @second_sid_address = second_sid_address
      @third_sid_address = third_sid_address
    end

    # A PSID speed-bit set for a subtune means CIA-timed playback. This tool
    # captures PAL vertical-blank players only, rather than silently exporting
    # incorrect timing for a CIA player.
    def cia_timed?(song)
      (speed & (1 << (song - 1))).positive?
    end

    def multi_sid?
      !second_sid_address.zero? || !third_sid_address.zero?
    end

    def ntsc_only?
      ((flags >> 2) & 0b11) == 0b10
    end

    private
    def self.read_word(bytes)
      (bytes[0].ord << 8) + bytes[1].ord
    end

    def self.read_long_word(bytes)
      (bytes[0].ord << 24) + (bytes[1].ord << 16) + (bytes[2].ord << 8) + bytes[3].ord
    end

    def self.read_null_terminated_string(bytes)
      first_null = bytes.index("\0") || 32
      bytes.byteslice(0, first_null)
    end

    def self.read_bytes(bytes)
      bytes.chars.map(&:ord)
    end
  end
end
