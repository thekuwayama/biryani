module Biryani
  module FrameType
    DATA          = 0x00
    HEADERS       = 0x01
    PRIORITY      = 0x02
    RST_STREAM    = 0x03
    SETTINGS      = 0x04
    PUSH_PROMISE  = 0x05
    PING          = 0x06
    GOAWAY        = 0x07
    WINDOW_UPDATE = 0x08
    CONTINUATION  = 0x09
  end
end

require_relative 'frame/continuation'
require_relative 'frame/data'
require_relative 'frame/goaway'
require_relative 'frame/headers'
require_relative 'frame/ping'
require_relative 'frame/priority'
require_relative 'frame/push_promise'
require_relative 'frame/rst_stream'
require_relative 'frame/settings'
require_relative 'frame/window_update'

module Biryani
  module Frame
    FRAME_MAP = {
      FrameType::DATA => Data,
      FrameType::HEADERS => Headers,
      FrameType::PRIORITY => Priority,
      FrameType::RST_STREAM => RstStream,
      FrameType::SETTINGS => Settings,
      FrameType::PUSH_PROMISE => PushPromise,
      FrameType::PING => Ping,
      FrameType::GOAWAY => Goaway,
      FrameType::WINDOW_UPDATE => WindowUpdate,
      FrameType::CONTINUATION => Continuation
    }.freeze
    private_constant :FRAME_MAP

    # @param io [IO]
    #
    # @return [Object] frame
    def self.read(io)
      s = io.read(4)
      len = (s[0...3] << 1).unpack1('C*')
      typ = s[4].unpack1('C*')

      FRAME_MAP[typ].read(s + io.read(len + 5))
      # TODO: unknown frame type
      # TODO: read error
    end
  end
end
