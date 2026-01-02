module Biryani
  # @param obj [Object]
  #
  # @return [Boolean]
  def self.err?(obj)
    obj.is_a?(StreamError) || obj.is_a?(ConnectionError)
  end

  # @param obj [Object, ConnectionError, StreamError] frame or error
  # @param last_stream_id [Integer]
  #
  # @return [Frame]
  def self.unwrap(obj, last_stream_id)
    case obj
    when ConnectionError
      obj.goaway(last_stream_id)
    when StreamError
      obj.rst_stream
    else
      obj
    end
  end
end
