module Sidtool
  class Synth
    attr_reader :start_frame
    attr_accessor :waveform, :attack, :decay
    attr_reader :sustain_length, :controls
    attr_accessor :release

    def initialize(start_frame)
      @start_frame = start_frame
      @controls = []
      @frequency = nil
      @released_at = nil
    end

    def frequency=(frequency)
      if @frequency
        previous_midi, current_midi = sid_frequency_to_nearest_midi(@frequency), sid_frequency_to_nearest_midi(frequency)

        @controls << [STATE.current_frame, current_midi] if previous_midi != current_midi
      end
      @frequency = frequency
    end

    def release!
      return if released?

      @released_at = STATE.current_frame
      length_of_ads = (STATE.current_frame - @start_frame) / STATE.frame_rate
      @attack, @decay, @sustain_length = adjust_ads(length_of_ads)
    end

    def released?
      !!@released_at
    end

    def stop!
      if released?
        @release = [@release, (STATE.current_frame - @released_at) / STATE.frame_rate].min
      else
        @release = 0
        release!
      end
    end

    def to_a
      [@start_frame, tone, @waveform, @attack.round(3), @decay.round(3), @sustain_length.round(3), @release.round(3), @controls]
    end

    def tone
      sid_frequency_to_nearest_midi(@frequency)
    end

    private

    def adjust_ads(length_of_ads)
      if length_of_ads < @attack
        [length_of_ads, 0, 0]
      elsif length_of_ads < @attack + @decay
        [@attack, length_of_ads - @attack, 0]
      else
        [@attack, @decay, length_of_ads - @attack - @decay]
      end
    end

    def sid_frequency_to_nearest_midi(sid_frequency)
      Sidtool.sid_frequency_to_midi(sid_frequency)
    end
  end
end
