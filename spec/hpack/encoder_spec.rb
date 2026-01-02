require_relative '../spec_helper'

RSpec.describe HPACK::Encoder do
  context do
    let(:encoder) do
      HPACK::Encoder.new(256)
    end

    it 'should encode' do
      # https://datatracker.ietf.org/doc/html/rfc7541#appendix-C.6.1
      expect(encoder.encode([
                              [':status', '302'],
                              ['cache-control', 'private'],
                              ['date', 'Mon, 21 Oct 2013 20:13:21 GMT'],
                              ['location', 'https://www.example.com']
                            ])).to eq [<<HEXDUMP.split.join].pack('H*')
  4882 6402 5885 aec3 771a 4b61 96d0 7abe
  9410 54d4 44a8 2005 9504 0b81 66e0 82a6
  2d1b ff6e 919d 29ad 1718 63c7 8f0b 97c8
  e9ae 82ae 43d3
HEXDUMP
      # https://datatracker.ietf.org/doc/html/rfc7541#appendix-C.6.2
      expect(encoder.encode([
                              [':status', '307'],
                              ['cache-control', 'private'],
                              ['date', 'Mon, 21 Oct 2013 20:13:21 GMT'],
                              ['location', 'https://www.example.com']
                            ])).to eq [<<HEXDUMP.split.join].pack('H*')
  4883 640e ffc1 c0bf
HEXDUMP
      # https://datatracker.ietf.org/doc/html/rfc7541#appendix-C.6.3
      expect(encoder.encode([
                              [':status', '200'],
                              ['cache-control', 'private'],
                              ['date', 'Mon, 21 Oct 2013 20:13:22 GMT'],
                              ['location', 'https://www.example.com'],
                              ['content-encoding', 'gzip'],
                              ['set-cookie', 'foo=ASDJKHQKBZXOQWEOPIUAXQWEOIU; max-age=3600; version=1']
                            ])).to eq [<<HEXDUMP.split.join].pack('H*')
  88c1 6196 d07a be94 1054 d444 a820 0595
  040b 8166 e084 a62d 1bff c05a 839b d9ab
  77ad 94e7 821d d7f2 e6c7 b335 dfdf cd5b
  3960 d5af 2708 7f36 72c1 ab27 0fb5 291f
  9587 3160 65c0 03ed 4ee5 b106 3d50 07
HEXDUMP
    end
  end
end
