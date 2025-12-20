module Biryani
  module Port
    # @return [Ractor]
    def port
      Ractor.new do
        loop do
          # TODO: using Ractor::Port.new for Ruby 4.0
          Ractor.yield Ractor.receive
        end
      end
    end
  end
end
