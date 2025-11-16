module Biryani
  module Frame
    class Ping < BinData::Record
      endian :big
      uint24 :payload_length, value: -> { 0x08 }
      uint8  :f_type, value: -> { FrameType::PING }
      bit7   :unused
      bit1   :ack
      bit1   :reserved
      bit31  :stream_id, value: -> { 0x00 }
      string :opaque, read_length: -> { 0x08 }
    end
  end
end
