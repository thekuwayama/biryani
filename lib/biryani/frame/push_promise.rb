module Biryani
  module Frame
    class PushPromise < BinData::Record
      endian :big
      uint24 :payload_length, value: -> { fragment.bytesize + 4 + (pad_length + 1) * padded.value }
      uint8  :f_type, value: -> { FrameType::PUSH_PROMISE }
      bit4   :unused1
      bit1   :padded
      bit1   :end_headers
      bit2   :unused2
      bit1   :reserved1
      bit31  :stream_id
      uint8  :pad_length, onlyif: -> { padded.positive? }, value: -> { padding.bytesize }
      bit1   :reserved2
      bit31  :promised_stream_id
      string :fragment, read_length: :fragment_length
      string :padding, onlyif: -> { padded.positive? }, read_length: -> { pad_length }

      def fragment_length
        len = payload_length - 4
        len -= pad_length + 1 if padded.positive?

        len
      end
    end
  end
end
