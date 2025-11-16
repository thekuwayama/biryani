module Biryani
  module Frame
    class PushPromise < BinData::Record
      endian :big
      uint24 :payload_length
      uint8  :f_type, value: -> { FrameType::PUSH_PROMISE }
      bit4   :unused1
      bit1   :padded
      bit1   :end_headers
      bit2   :unused2
      bit1   :reserved1
      bit31  :stream_id
      uint8  :pad_length, onlyif: :padded?
      bit1   :reserved2
      bit31  :promised_stream_id
      string :fragment, read_length: :fragment_length
      string :padding, read_length: -> { pad_length }

      def fragment_length
        len = payload_length - 4
        len -= pad_length + 1 if padded

        len
      end
    end
  end
end
