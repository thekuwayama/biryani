module Biryani
  module Frame
    class Data < BinData::Record
      endian :big
      uint24 :payload_length
      uint8  :f_type, value: -> { FrameType::DATA }
      bit4   :unused1
      bit1   :padded
      bit2   :unused2
      bit1   :end_stream
      bit1   :reserved
      bit31  :stream_id
      uint8  :pad_length, onlyif: :padded?
      string :data, read_length: :data_length
      string :padding, read_length: -> { pad_length }

      def data_length
        payload_length - (padded ? pad_length + 1 : 0)
      end
    end
  end
end
