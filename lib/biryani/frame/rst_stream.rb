module Biryani
  module Frame
    class RstStream < BinData::Record
      endian :big
      uint24 :payload_length, value: -> { 0x04 }
      uint8  :f_type, value: -> { 0x03 }
      bit8   :unused
      bit1   :reserved
      bit31  :stream_id
      uint32 :error_code
    end
  end
end
