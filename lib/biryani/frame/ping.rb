module Biryani
  module Frame
    class Ping < BinData::Record
      endian :big
      uint24 :payload_length, value: -> { 0x08 }
      uint8  :f_type, value: -> { 0x06 }
      bit7   :unused
      bit1   :ack
      bit1   :reserved
      bit31  :stream_id, value: -> { 0x00 }
      uint64 :opaque
    end
  end
end
