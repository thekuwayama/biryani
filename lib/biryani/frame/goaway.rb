module Biryani
  module Frame
    class Goaway < BinData::Record
      endian :big
      uint24 :payload_length, value: -> { debug.bytesize + 8 }
      uint8  :f_type, value: -> { FrameType::GOAWAY }
      bit8   :unused
      bit1   :reserved1
      bit31  :stream_id, value: -> { 0x00 }
      bit1   :reserved2
      bit31  :last_stream_id
      uint32 :error_code
      string :debug, read_length: -> { payload_length - 8 }
    end
  end
end
