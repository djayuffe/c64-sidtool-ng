module Sidtool
  class State
    attr_reader :current_frame

    def initialize
      @current_frame = 0
    end

    def advance!
      @current_frame += 1
    end

    def reset!
      @current_frame = 0
    end
  end
end
