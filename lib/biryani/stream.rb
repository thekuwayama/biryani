require_relative 'frame'
require_relative 'state'

module Biryani
  class Stream
    attr_reader :rport

    # @param stream_id [Integer]
    def initialize(stream_id)
      @stream_id = stream_id
      @state = State.new
      @rport = Ractor.new do
        _frame, _wport = Ractor.receive
        case frame.f_type
        when FrameType::DATA
          # TODO: how to bucket DATA & HEADERS ?
          # TODO: return frame via wport
        when FrameType::HEADERS
          # TODO: how to bucket DATA & HEADERS ?
          # TODO: return frame via wport
        end
      end
    end

    # @param frame [Object]
    # @param direction [:send, :recv]
    def transition_state!(frame, direction)
      @state.transition!(frame, direction)
    end

    # @return [Boolean]
    def closed?
      @state == closed
    end
  end
end
