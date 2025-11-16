module Biryani
  module Frame
    class WindowUpdate < BinData::Record
      endian :big
      uint24 :payload_length, value: -> { 0x04 }
      uint8  :f_type, value: -> { 0x08 }
      bit8   :unused
      bit1   :reserved1
      bit31  :stream_id
      bit1   :reserved2
      bit31  :window_size_increment
    end
  end
end
