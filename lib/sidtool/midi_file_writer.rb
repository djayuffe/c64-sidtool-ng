module Sidtool
  class MidiFileWriter
    DeltaTime = Struct.new(:time) do
      def bytes
        quantity = time
        raise ArgumentError, "MIDI delta time cannot be negative: #{time}" if quantity.negative?

        seven_bit_segments = []
        max_iterations = 100  # Safeguard against infinite loops
        iterations = 0

        while true
          seven_bit_segments << (quantity & 127)
          quantity >>= 7
          break if quantity == 0 || iterations >= max_iterations
          iterations += 1
        end

        result = seven_bit_segments.reverse.map { |segment| segment | 128 }
        result[-1] &= 127
        result
      end
    end

    TrackName = Struct.new(:name) do
      def bytes
        [
          0xFF, 0x03,
          name.length,
          *name.bytes
        ]
      end
    end

    TimeSignature = Struct.new(:numerator, :denominator_power_of_two, :clocks_per_metronome_click, :number_of_32th_nodes_per_24_clocks) do
      def bytes
        [
          0xFF, 0x58, 0x04,
          numerator,
          denominator_power_of_two,
          clocks_per_metronome_click,
          number_of_32th_nodes_per_24_clocks
        ]
      end
    end

    KeySignature = Struct.new(:sharps_or_flats, :is_major) do
      def bytes
        [
          0xFF, 0x59, 0x02,
          sharps_or_flats,
          is_major ? 0 : 1
        ]
      end
    end

    EndOfTrack = Struct.new(:nothing) do
      def bytes
        [
          0xFF, 0x2F, 0x00
        ]
      end
    end

    Tempo = Struct.new(:microseconds_per_quarter_note) do
      def bytes
        value = microseconds_per_quarter_note
        [0xFF, 0x51, 0x03, (value >> 16) & 255, (value >> 8) & 255, value & 255]
      end
    end

    ProgramChange = Struct.new(:channel, :program_number) do
      def bytes
        raise "Channel too big: #{channel}" if channel > 15
        raise "Program number is too big: #{program_number}" if program_number > 127
        [
          0xC0 + channel,
          program_number
        ]
      end
    end

    NoteOn = Struct.new(:channel, :key) do
      def bytes
        raise "Channel too big: #{channel}" if channel > 15
        raise "Key is too big: #{key}" if key > 127
        [
          0x90 + channel,
          key,
          40 # Default velocity
        ]
      end
    end

    NoteOff = Struct.new(:channel, :key) do
      def bytes
        raise "Channel too big: #{channel}" if channel > 15
        raise "Key is too big: #{key}" if key > 127
        [
          0x80 + channel,
          key,
          40 # Default velocity
        ]
      end
    end

    TICKS_PER_QUARTER_NOTE = 480

    def initialize(synths_for_voices, frame_rate: FRAMES_PER_SECOND)
      @synths_for_voices = synths_for_voices
      @frame_rate = frame_rate.to_f
      raise ArgumentError, 'Frame rate must be positive' unless @frame_rate.positive?

      @tempo_microseconds = (1_000_000 * TICKS_PER_QUARTER_NOTE / @frame_rate).round
      unless @tempo_microseconds.between?(1, 0xFF_FF_FF)
        raise ArgumentError, "Frame rate cannot be represented by MIDI tempo: #{@frame_rate}"
      end
    end

    def write_to(path)
      tracks = @synths_for_voices.map { |synths| build_track(synths) }

      File.open(path, 'wb') do |file|
        write_header(file)
        tracks.each_with_index { |track, index| write_track(file, track, "Voice #{index + 1}") }
      end
    end

    def build_track(synths)
      waveforms = [:tri, :saw, :pulse, :noise]

      track = []
      current_frame = 0
      synths.each do |synth|
        channel = waveforms.index(synth.waveform) || raise("Unknown waveform #{synth.waveform}")
        track << DeltaTime.new(synth.start_frame - current_frame)
        track << NoteOn.new(channel, synth.tone)
        current_frame = synth.start_frame

        current_tone = synth.tone
        synth.controls.each do |start_frame, tone|
          track << DeltaTime.new(start_frame - current_frame)
          track << NoteOff.new(channel, current_tone)
          track << DeltaTime.new(0)
          track << NoteOn.new(channel, tone)
          current_tone = tone
          current_frame = start_frame
        end

        end_frame = [current_frame, synth.start_frame + (@frame_rate * (synth.attack + synth.decay + synth.sustain_length)).to_i].max
        track << DeltaTime.new(end_frame - current_frame)
        track << NoteOff.new(channel, current_tone)
        current_frame = end_frame
      end

      # Optimization: Consolidate consecutive NoteOff and NoteOn events for the same tone
      optimized_track = consolidate_events(track)
      optimized_track
    end

    private

    def consolidate_events(track)
      consolidated = []
      skip_next = false
      track.each_with_index do |event, i|
        if skip_next
          skip_next = false
          next
        end

        next_event = track[i + 1]
        if event.is_a?(NoteOff) && next_event.is_a?(NoteOn) && event.key == next_event.key
          # Skip the NoteOff and the next NoteOn as they cancel each other out
          skip_next = true
        else
          consolidated << event
        end
      end
      consolidated
    end

    def write_header(file)
      # Type
      file << 'MThd'

      # Length
      write_uint32(file, 6)

      # Format
      write_uint16(file, 1)

      # Number of tracks. MIDI format 1 stores one track for each SID voice.
      write_uint16(file, @synths_for_voices.length)

      # One MIDI tick equals one source frame. The tempo event on every track
      # maps those ticks to the PAL or NTSC frame rate.
      write_uint16(file, TICKS_PER_QUARTER_NOTE)
    end

    def write_track(file, track, name)
      track_with_metadata = [
        DeltaTime[0], TrackName[name],
        DeltaTime[0], Tempo[@tempo_microseconds],
        DeltaTime[0], TimeSignature[4, 2, 24, 8],
        DeltaTime[0], KeySignature[0, 0],

        DeltaTime[0], ProgramChange[0, 1],  # Triangular - maps to piano
        DeltaTime[0], ProgramChange[1, 25], # Saw - maps to guitar
        DeltaTime[0], ProgramChange[2, 33], # Pulse - maps to bass
        DeltaTime[0], ProgramChange[3, 41]  # Noise -  maps to strings
      ] +
      track +
      [
        DeltaTime[0], EndOfTrack[]
      ]
      track_bytes = track_with_metadata.flat_map(&:bytes)

      # Type
      file << 'MTrk'

      # Length
      write_uint32(file, track_bytes.length)

      # MIDI is an octet stream. `c` is signed and rejects values above 127,
      # including the standard 0xFF meta-event marker.
      file << track_bytes.pack('C*')
    end

    def write_uint32(file, value)
      bytes = [(value >> 24) & 255, (value >> 16) & 255, (value >> 8) & 255, value & 255]
      file << bytes.pack('C4')
    end

    def write_uint16(file, value)
      bytes = [(value >> 8) & 255, value & 255]
      file << bytes.pack('C2')
    end

    def write_byte(file, value)
      bytes = [value & 255]
      file << bytes.pack('C')
    end
  end
end
