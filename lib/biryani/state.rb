module Biryani
  class State
    def initialize
      @state = :idle
    end

    # @param frame [Object]
    # @param direction [:send, :recv]
    def transition!(frame, direction)
      @state = self.class.next(@state, frame, direction)
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
    # @param state [:idle, :open, :reserved_local, :reserved_remote, :half_closed_local, :half_closed_remote, :closed]
    # @param frame [Object]
    # @param direction [:send, :recv]
    #
    # @return [:idle, :open, :reserved_local, :reserved_remote, :half_closed_local, :half_closed_remote, :closed]
    # rubocop: disable Metrics/AbcSize
    # rubocop: disable Metrics/CyclomaticComplexity
    # rubocop: disable Metrics/MethodLength
    # rubocop: disable Metrics/PerceivedComplexity
    def self.next(state, frame, direction)
      case [state, frame.f_type, direction]
      in [_, FrameType::SETTINGS, _]
        state
      in [_, FrameType::GOAWAY, _]
        state
      in [:idle, FrameType::HEADERS, :recv] if frame.end_stream?
        :half_closed_remote
      in [:idle, FrameType::HEADERS, :send] if frame.end_stream?
        :half_closed_local
      in [:idle, FrameType::HEADERS, _]
        :open
      in [:idle, FrameType::PUSH_PROMISE, :recv]
        :reserved_remote
      in [:idle, FrameType::PUSH_PROMISE, :send]
        :reserved_local
      in [:idle, FrameType::PRIORITY, _]
        :idle
      in [:open, FrameType::DATA, :recv] if frame.end_stream?
        :half_closed_remote
      in [:open, FrameType::HEADERS, :recv] if frame.end_stream?
        :half_closed_remote
      in [:open, FrameType::DATA, :send] if frame.end_stream?
        :half_closed_local
      in [:open, FrameType::HEADERS, :send] if frame.end_stream?
        :half_closed_local
      in [:open, FrameType::RST_STREAM, _]
        :closed
      in [:open, _, _]
        :open
      in [:reserved_local, FrameType::HEADERS, :send]
        :half_closed_remote
      in [:reserved_local, FrameType::RST_STREAM, _]
        :closed
      in [:reserved_remote, FrameType::HEADERS, :recv]
        :half_closed_local
      in [:reserved_remote, FrameType::RST_STREAM, _]
        :closed
      in [:half_closed_local, FrameType::PRIORITY, :send]
        :half_closed_local
      in [:half_closed_local, FrameType::WINDOW_UPDATE, :send]
        :half_closed_local
      in [:half_closed_local, FrameType::RST_STREAM, :send]
        :closed
      in [:half_closed_local, FrameType::DATA, :recv] if f.end_stream?
        :closed
      in [:half_closed_local, FrameType::HEADERS, :recv] if f.end_stream?
        :closed
      in [:half_closed_local, FrameType::RST_STREAM, :recv]
        :closed
      in [:half_closed_local, _, :recv]
        :half_closed_local
      in [:half_closed_remote, FrameType::DATA, :send] if f.end_stream?
        :closed
      in [:half_closed_remote, FrameType::HEADERS, :send] if f.end_stream?
        :closed
      in [:half_closed_remote, FrameType::RST_STREAM, :send]
        :closed
      in [:half_closed_remote, _, :recv]
        # TODO: stream_closed error
      in [:closed, FrameType::PRIORITY, :send]
        :closed
      in [:closed, FrameType::WINDOW_UPDATE, :recv]
        :closed
      in [:closed, FrameType::PRIORITY, :recv]
        :closed
      in [:closed, FrameType::RST_STREAM, :recv]
        :closed
      in [:closed, _, :recv]
        # TODO: stream_closed error
      else
        # TODO: protocol_error error
      end
    end
    # rubocop: enable Metrics/AbcSize
    # rubocop: enable Metrics/CyclomaticComplexity
    # rubocop: enable Metrics/MethodLength
    # rubocop: enable Metrics/PerceivedComplexity

    # @return [Boolean]
    def closed?
      @state == :closed
    end
  end
end
