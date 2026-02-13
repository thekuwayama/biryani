module Biryani
  class State
    def initialize
      @state = :idle
    end

    # @param frame [Object]
    # @param direction [:send, :recv]
    def transition!(frame, direction)
      obj = self.class.next(@state, frame, direction)
      return obj if Biryani.err?(obj)

      @state = obj
    end

    #                          +--------+
    #                  send PP |        | recv PP
    #                 ,--------+  idle  +--------.
    #                /         |        |         \
    #               v          +--------+          v
    #        +----------+          |           +----------+
    #        |          |          | send H /  |          |
    # ,------+ reserved |          | recv H    | reserved +------.
    # |      | (local)  |          |           | (remote) |      |
    # |      +---+------+          v           +------+---+      |
    # |          |             +--------+             |          |
    # |          |     recv ES |        | send ES     |          |
    # |   send H |     ,-------+  open  +-------.     | recv H   |
    # |          |    /        |        |        \    |          |
    # |          v   v         +---+----+         v   v          |
    # |      +----------+          |           +----------+      |
    # |      |   half-  |          |           |   half-  |      |
    # |      |  closed  |          | send R /  |  closed  |      |
    # |      | (remote) |          | recv R    | (local)  |      |
    # |      +----+-----+          |           +-----+----+      |
    # |           |                |                 |           |
    # |           | send ES /      |       recv ES / |           |
    # |           |  send R /      v        send R / |           |
    # |           |  recv R    +--------+   recv R   |           |
    # | send R /  `----------->|        |<-----------'  send R / |
    # | recv R                 | closed |               recv R   |
    # `----------------------->|        |<-----------------------'
    #                          +--------+
    # https://datatracker.ietf.org/doc/html/rfc9113#section-5.1
    #
    # @param state [Symbol]
    # @param frame [Object]
    # @param direction [:send, :recv]
    #
    # @raise [StandardError]
    #
    # @return [Symbol, ConnectionError]
    # rubocop: disable Metrics/AbcSize
    # rubocop: disable Metrics/CyclomaticComplexity
    # rubocop: disable Metrics/MethodLength
    # rubocop: disable Metrics/PerceivedComplexity
    def self.next(state, frame, direction)
      typ = frame.f_type
      case [state, direction, typ]
      # idle
      in [:idle, :send, FrameType::PUSH_PROMISE]
        :reserved_local
      in [:idle, :recv, FrameType::HEADERS] if frame.end_stream? && frame.end_headers?
        :half_closed_remote
      in [:idle, :recv, FrameType::HEADERS] if frame.end_headers?
        :receiving_data
      in [:idle, :recv, FrameType::HEADERS] if frame.end_stream?
        :receiving_continuation
      in [:idle, :recv, FrameType::HEADERS]
        :receiving_continuation_and_data
      in [:idle, :recv, FrameType::PRIORITY]
        state

      # receiving_continuation_and_data
      in [:receiving_continuation_and_data, :recv, FrameType::WINDOW_UPDATE]
        state
      in [:receiving_continuation_and_data, :recv, FrameType::CONTINUATION] if frame.end_headers?
        :receiving_data
      in [:receiving_continuation_and_data, :recv, FrameType::CONTINUATION]
        state
      in [:receiving_continuation_and_data, _, FrameType::RST_STREAM]
        :closed

      # receiving_continuation
      in [:receiving_continuation, :recv, FrameType::DATA] if frame.end_stream?
        :half_closed_remote
      in [:receiving_continuation, :recv, FrameType::DATA]
        :receiving_data
      in [:receiving_continuation, :recv, FrameType::WINDOW_UPDATE]
        state
      in [:receiving_continuation, :recv, FrameType::CONTINUATION] if frame.end_headers?
        :half_closed_remote
      in [:receiving_continuation, :recv, FrameType::CONTINUATION]
        state
      in [:receiving_continuation, _, FrameType::RST_STREAM]
        :closed

      # receiving_data
      in [:receiving_data, :recv, FrameType::DATA] if frame.end_stream?
        :half_closed_remote
      in [:receiving_data, :recv, FrameType::DATA]
        state
      in [:receiving_data, :recv, FrameType::HEADERS] if !frame.end_stream?
        unexpected(ErrorCode::PROTOCOL_ERROR, state, typ, direction)
      in [:receiving_data, :recv, FrameType::HEADERS] if frame.end_headers?
        :half_closed_remote
      in [:receiving_data, :recv, FrameType::HEADERS]
        :receiving_trailer_continuation
      in [:receiving_data, :recv, FrameType::PRIORITY]
        state
      in [:receiving_data, _, FrameType::RST_STREAM]
        :closed
      in [:receiving_data, _, FrameType::WINDOW_UPDATE]
        state

      # receiving_trailer_headers
      in [:receiving_trailer_headers, :recv, FrameType::HEADERS] if !frame.end_stream?
        unexpected(ErrorCode::PROTOCOL_ERROR, state, typ, direction)
      in [:receiving_trailer_headers, :recv, FrameType::HEADERS] if frame.end_headers?
        :half_closed_remote
      in [:receiving_trailer_headers, :recv, FrameType::HEADERS]
        :receiving_trailer_continuation
      in [:receiving_trailer_headers, :recv, FrameType::WINDOW_UPDATE]
        state

      # receiving_trailer_continuation
      in [:receiving_trailer_continuation, :recv, FrameType::WINDOW_UPDATE]
        state
      in [:receiving_trailer_continuation, :recv, FrameType::CONTINUATION] if frame.end_headers?
        :half_closed_remote
      in [:receiving_trailer_continuation, :recv, FrameType::CONTINUATION]
        :receiving_trailer_continuation
      in [:receiving_trailer_continuation, _, FrameType::RST_STREAM]
        :closed

      # reserved_remote
      in [:reserved_remote, _, _]
        # TODO
        state

      # reserved_local
      in [:reserved_local, _, _]
        # TODO
        state

      # half_closed_remote
      in [:half_closed_remote, :send, FrameType::HEADERS] if frame.end_stream? && frame.end_headers?
        :closed
      in [:half_closed_remote, :send, FrameType::HEADERS] if frame.end_headers?
        :sending_data
      in [:half_closed_remote, :send, FrameType::HEADERS] if frame.end_stream?
        :sending_continuation
      in [:half_closed_remote, :send, FrameType::HEADERS]
        :sending_continuation_and_data
      in [:half_closed_remote, :recv, FrameType::PRIORITY]
        state
      in [:half_closed_remote, _, FrameType::RST_STREAM]
        :closed
      in [:half_closed_remote, _, FrameType::WINDOW_UPDATE]
        state

      # sending_continuation_and_data
      in [:sending_continuation_and_data, :send, FrameType::CONTINUATION] if frame.end_headers?
        :sending_data
      in [:sending_continuation_and_data, :send, FrameType::CONTINUATION]
        state
      in [:sending_continuation_and_data, :send, _]
        unreachable(state, typ, direction)
      in [:sending_continuation_and_data, :recv, FrameType::PRIORITY]
        state
      in [:sending_continuation_and_data, :recv, FrameType::WINDOW_UPDATE]
        state
      in [:sending_continuation_and_data, _, FrameType::RST_STREAM]
        :closed

      # sending_continuation
      in [:sending_continuation, :send, FrameType::CONTINUATION] if frame.end_headers?
        :closed
      in [:sending_continuation, :send, FrameType::CONTINUATION]
        state
      in [:sending_continuation, :send, _]
        unreachable(state, typ, direction)
      in [:sending_continuation, :recv, FrameType::PRIORITY]
        state
      in [:sending_continuation, :recv, FrameType::WINDOW_UPDATE]
        state
      in [:sending_continuation, _, FrameType::RST_STREAM]
        :closed

      # sending_data
      in [:sending_data, :send, FrameType::DATA] if frame.end_stream?
        :closed
      in [:sending_data, :send, FrameType::DATA]
        state
      in [:sending_data, :send, _]
        unreachable(state, typ, direction)
      in [:sending_data, :recv, FrameType::PRIORITY]
        state
      in [:sending_data, :recv, FrameType::WINDOW_UPDATE]
        state
      in [:sending_data, _, FrameType::RST_STREAM]
        :closed

      # closed
      in [:closed, :send, _]
        unreachable(state, typ, direction)
      in [:closed, :recv, FrameType::PRIORITY]
        state
      in [:closed, _, FrameType::RST_STREAM]
        state

      # other
      in [_, :send, _]
        unreachable(state, typ, direction)
      in [_, :recv, _]
        unexpected(ErrorCode::STREAM_CLOSED, state, typ, direction)
      end
    end
    # rubocop: enable Metrics/AbcSize
    # rubocop: enable Metrics/CyclomaticComplexity
    # rubocop: enable Metrics/MethodLength
    # rubocop: enable Metrics/PerceivedComplexity

    def self.unexpected(error_code, state, typ, direction)
      ConnectionError.new(error_code, "#{direction} unexpected #{format('0x%02x', typ)} frame in #{state}")
    end

    def self.unreachable(state, typ, direction)
      raise "#{direction} unexpected #{format('0x%02x', typ)} frame in #{state}"
    end

    def close
      @state = :closed
    end

    # @return [Boolean]
    def closed?
      @state == :closed
    end

    # @return [Boolean]
    def idle?
      @state == :idle
    end

    # @return [Boolean]
    def active?
      !%i[idle reserved_local reserved_remote closed].include?(@state)
    end

    # @return [Boolean]
    def half_closed_remote?
      @state == :half_closed_remote
    end

    # @return [Boolean]
    def receiving_continuation?
      %i[receiving_continuation receiving_continuation_and_data receiving_trailer_continuation].include?(@state)
    end
  end
end
