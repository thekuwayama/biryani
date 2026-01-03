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
      case [state, typ, direction]
      # idle
      in [:idle, FrameType::HEADERS, :recv] if frame.end_stream? && frame.end_headers?
        :half_closed_remote
      in [:idle, FrameType::HEADERS, :recv] if frame.end_headers?
        :receiving_data
      in [:idle, FrameType::HEADERS, :recv] if frame.end_stream?
        :receiving_continuation
      in [:idle, FrameType::HEADERS, :recv]
        :receiving_continuation_data
      in [:idle, FrameType::PRIORITY, :recv]
        state
      in [:idle, FrameType::PUSH_PROMISE, :send]
        :reserved_local
      in [:idle, _, _]
        unexpected(ErrorCode::PROTOCOL_ERROR, state, typ, direction)

      # receiving_continuation_data
      in [:receiving_continuation_data, FrameType::RST_STREAM, _]
        :closed
      in [:receiving_continuation_data, FrameType::WINDOW_UPDATE, :recv]
        state
      in [:receiving_continuation_data, FrameType::CONTINUATION, :recv] if frame.end_headers?
        :receiving_data
      in [:receiving_continuation_data, FrameType::CONTINUATION, :recv]
        state
      in [:receiving_continuation_data, _, _]
        unexpected(ErrorCode::PROTOCOL_ERROR, state, typ, direction)

      # receiving_continuation
      in [:receiving_continuation, FrameType::RST_STREAM, _]
        :closed
      in [:receiving_continuation, FrameType::WINDOW_UPDATE, :recv]
        state
      in [:receiving_continuation, FrameType::CONTINUATION, :recv] if frame.end_headers?
        :half_closed_remote
      in [:receiving_continuation, FrameType::CONTINUATION, :recv]
        state
      in [:receiving_continuation, _, _]
        unexpected(ErrorCode::PROTOCOL_ERROR, state, typ, direction)

      # receiving_data
      in [:receiving_data, FrameType::DATA, :recv] if frame.end_stream?
        :half_closed_remote
      in [:receiving_data, FrameType::DATA, :recv]
        state
      in [:receiving_data, FrameType::RST_STREAM, _]
        :closed
      in [:receiving_data, FrameType::WINDOW_UPDATE, _]
        state
      in [:receiving_data, _, _]
        unexpected(ErrorCode::PROTOCOL_ERROR, state, typ, direction)

      # reserved_remote
      in [:reserved_remote, _, _]
        # TODO
        state

      # reserved_local
      in [:reserved_local, _, _]
        # TODO
        state

      # half_closed_remote
      in [:half_closed_remote, FrameType::HEADERS, :send] if frame.end_stream? && frame.end_headers?
        :closed
      in [:half_closed_remote, FrameType::HEADERS, :send] if frame.end_headers?
        :sending_data
      in [:half_closed_remote, FrameType::HEADERS, :send] if frame.end_stream?
        :sending_continuation
      in [:half_closed_remote, FrameType::HEADERS, :send]
        :sending_continuation_data
      in [:half_closed_remote, FrameType::PRIORITY, :recv]
        state
      in [:half_closed_remote, FrameType::RST_STREAM, _]
        :closed
      in [:half_closed_remote, FrameType::WINDOW_UPDATE, _]
        state
      in [:half_closed_remote, _, :recv]
        unexpected(ErrorCode::STREAM_CLOSED, state, typ, direction)
      in [:half_closed_local, _, :send]
        unreachable(state, typ, direction)

      # sending_continuation_data
      in [:sending_continuation_data, FrameType::RST_STREAM, :send]
        :closed
      in [:sending_continuation_data, FrameType::WINDOW_UPDATE, :recv]
        state
      in [:sending_continuation_data, FrameType::CONTINUATION, :send] if frame.end_headers?
        :sending_data
      in [:sending_continuation_data, FrameType::CONTINUATION, :send]
        state
      in [:sending_continuation_data, _, :send]
        unreachable(state, typ, direction)
      in [:sending_continuation_data, _, :recv]
        unexpected(ErrorCode::PROTOCOL_ERROR, state, typ, direction)

      # sending_continuation
      in [:sending_continuation, FrameType::RST_STREAM, :send]
        :closed
      in [:sending_continuation, FrameType::WINDOW_UPDATE, :recv]
        state
      in [:sending_continuation, FrameType::CONTINUATION, :send] if frame.end_headers?
        :closed
      in [:sending_continuation, FrameType::CONTINUATION, :send]
        state
      in [:sending_continuation, _, :send]
        unreachable(state, typ, direction)
      in [:sending_continuation, _, :recv]
        unexpected(ErrorCode::PROTOCOL_ERROR, state, typ, direction)

      # sending_data
      in [:sending_data, FrameType::DATA, :send] if frame.end_stream?
        :closed
      in [:sending_data, FrameType::WINDOW_UPDATE, :recv]
        state
      in [:sending_data, FrameType::DATA, :send]
        state
      in [:sending_data, FrameType::RST_STREAM, :send]
        :closed
      in [:sending_continuation, _, :send]
        unreachable(state, typ, direction)
      in [:sending_continuation, _, :recv]
        unexpected(ErrorCode::PROTOCOL_ERROR, state, typ, direction)

      # closed
      in [:closed, FrameType::RST_STREAM, :recv]
        state
      in [:closed, _, :send]
        unreachable(state, typ, direction)
      in [:closed, _, :recv]
        unexpected(ErrorCode::STREAM_CLOSED, state, typ, direction)

      # other
      in [_, _, :send]
        unreachable(state, typ, direction)
      in [_, _, :recv]
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
  end
end
