module Biryani
  module Frame
    class Priority < BinData::Record
      endian :big
      uint24 :payload_length, value: -> { 0x05 }
      uint8  :f_type, value: -> { FrameType::PRIORITY }
      bit8   :unused
      bit1   :reserved
      bit31  :stream_id
      bit1   :exclusive
      bit31  :stream_dependency
      uint8  :weight
    end
  end
end
