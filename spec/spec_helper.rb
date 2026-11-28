require 'biryani'

# rubocop: disable Style/MixinUsage
include Biryani
# rubocop: enable Style/MixinUsage

def do_nothing_spawner
  Ractor.make_shareable(Stream::Spawner.new(Ractor.shareable_proc { |_, _| }))
end
