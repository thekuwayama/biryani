module Biryani
  module Frame
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
