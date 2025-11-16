module Biryani
  module Frame
    class Continuation < BinData::Record
      endian :big
      uint24 :payload_length
      uint8  :f_type, value: -> { 0x09 }
      bit5   :unused1
      bit1   :end_headers
      bit2   :unused2
      bit31  :stream_id
      bit1   :reserved2
      string :fragment, read_length: -> { payload_length }
    end
  end
end
