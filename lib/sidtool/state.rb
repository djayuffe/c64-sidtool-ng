module Sidtool
  class State
    attr_reader :current_frame, :frame_rate, :clock_frequency

    def initialize
      reset!
    end

    def advance!
      @current_frame += 1
    end

    def reset!(frame_rate: FRAMES_PER_SECOND)
      @current_frame = 0
      @frame_rate = frame_rate.to_f
      @clock_frequency = @frame_rate == 60.0 ? NTSC_CLOCK_FREQUENCY : PAL_CLOCK_FREQUENCY
    end
  end
end
