module Biryani
  module Frame
    class Headers < BinData::Record
      endian :big
      uint24 :payload_length, value: -> { fragment.bytesize + (pad_length + 1) * padded.value + 5 * priority.value }
      uint8  :f_type, value: -> { FrameType::HEADERS }
      bit2   :unused1
      bit1   :priority
      bit1   :unused2
      bit1   :padded
      bit1   :end_headers
      bit1   :unused3
      bit1   :end_stream
      bit1   :reserved
      bit31  :stream_id
      uint8  :pad_length, onlyif: -> { padded.positive? }, value: -> { padding.bytesize }
      bit1   :exclusive, onlyif: -> { priority.positive? }
      bit31  :stream_dependency, onlyif: -> { priority.positive? }
      uint8  :weight, onlyif: -> { priority.positive? }
      string :fragment, read_length: -> { fragment_length }
      string :padding, onlyif: -> { padded.positive? }, read_length: -> { pad_length }

      def fragment_length
        len = payload_length
        len -= pad_length + 1 if padded.positive?
        len -= 5 if priority.positive?

        len
      end
    end
  end
end
