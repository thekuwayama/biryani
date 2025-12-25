module Biryani
  class Stream
    attr_accessor :rx

    # @param tx [Ractor] port
    # @param err [Ractor] port
    # rubocop: disable Metrics/AbcSize
    # rubocop: disable Metrics/BlockLength
    # rubocop: disable Metrics/CyclomaticComplexity
    # rubocop: disable Metrics/MethodLength
    def initialize(tx, err)
      @rx = Ractor.new(tx, err) do |tx, err|
        bucket = FieldsBucket.new
        content = StringIO.new

        loop do
          recv_frame = Ractor.receive

          case recv_frame.f_type
          when FrameType::DATA
            content << recv_frame.data

            if recv_frame.end_stream?
              obj = bucket.http_request(content)
              if obj.is_a?(ConnectionError)
                err << obj
                break
              end

              # TODO: Hello, world!
              tx << Frame::RawHeaders.new(true, false, recv_frame.stream_id, nil, nil, [[':status', '200']], nil)
              tx << Frame::Data.new(true, recv_frame.stream_id, 'Hello, world!', nil)
              break
            end
          when FrameType::HEADERS
            # TODO: check recv_frame.end_headers?
            obj = bucket.merge!(recv_frame.fields)
            if obj.is_a?(ConnectionError)
              err << obj
              break
            end

            if recv_frame.end_stream?
              obj = bucket.http_request(content)
              if obj.is_a?(ConnectionError)
                err << obj
                break
              end

              # TODO: Hello, world!
              tx << Frame::RawHeaders.new(true, false, recv_frame.stream_id, nil, nil, [[':status', '200']], nil)
              tx << Frame::Data.new(true, recv_frame.stream_id, 'Hello, world!', nil)
              break
            end
          when FrameType::PUSH_PROMISE
            # TODO
          when FrameType::CONTINUATION
            # TODO: check recv_frame.end_headers?
            bucket.merge!(recv_frame.fields)
          else
            err << ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'internal error')
          end
        end
      end
    end
    # rubocop: enable Metrics/AbcSize
    # rubocop: enable Metrics/BlockLength
    # rubocop: enable Metrics/CyclomaticComplexity
    # rubocop: enable Metrics/MethodLength
  end
end
