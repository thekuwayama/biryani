require 'open3'
require 'socket'
require 'biryani'

# rubocop: disable Style/MixinUsage
include Biryani
# rubocop: enable Style/MixinUsage

PORT = 8888
JUNIT_REPORT_DIR = "#{__dir__}/reports".freeze

def which(cmd)
  o, = Open3.capture3("which #{cmd}")
  warn "conformance task require `#{cmd}`. Install `#{cmd}`." if o.empty?
end
