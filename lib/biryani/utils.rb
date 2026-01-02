module Biryani
  # @param obj [Object]
  #
  # @return [Boolean]
  def self.err?(obj)
    obj.is_a?(StreamError) || obj.is_a?(ConnectionError)
  end
end
