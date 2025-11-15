module Biryani
  module Frame
    class Headers < BinData::Record
      endian :big
      uint24 :payload_length
      uint8  :f_type, value: -> { 0x01 }
      bit2   :unused1
      bit1   :priority
      bit1   :unused2
      bit1   :padded
      bit1   :end_headers
      bit1   :unused3
      bit1   :end_stream
      bit1   :reserved
      bit31  :stream_id
      uint8  :pad_length, onlyif: :padded?
      bit1   :exclusive, onlyif: :priority?
      bit31  :stream_dependency, onlyif: :priority?
      uint8  :weight, onlyif: :priority?
      string :fragment, read_length: :fragment_length
      string :padding, read_length: -> { pad_length }

      def fragment_length
        len = payload_length
        len -= pad_length + 1 if padded
        len -= 5 if priority

        len
      end
    end
  end
end
