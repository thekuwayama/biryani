module Biryani
  module Frame
    class Settings < BinData::Record
      endian :big
      uint24 :payload_length
      uint8  :f_type, value: -> { 0x04 }
      bit7   :unused
      bit1   :ack
      bit1   :reserved
      bit31  :stream_id, value: -> { 0x00 }
      array  :setting, initial_length: -> { payload_length / 6 } do
        uint16 :setting_id
        uint32 :setting_value
      end
    end
  end
end
