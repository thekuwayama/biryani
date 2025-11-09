module Biryani
  module HPACK
  end
end

Dir["#{File.dirname(__FILE__)}/hpack/*.rb"].sort.each { |f| require_relative f } # TODO: dependencies
