module Biryani
  module Frame
    class RstStream < BinData::Record
      endian :big
      uint24 :payload_length, value: -> { 0x04 }
      uint8  :f_type, value: -> { FrameType::RST_STREAM }
      bit8   :unused
      bit1   :reserved
      bit31  :stream_id
      uint32 :error_code
    end
  end
end
