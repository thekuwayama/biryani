require 'biryani'

# rubocop: disable Style/MixinUsage
include Biryani
# rubocop: enable Style/MixinUsage

def do_nothing_proc
  Ractor.shareable_proc { |_, _| }
end
