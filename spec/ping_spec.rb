require_relative 'spec_helper'

RSpec.describe Frame::Ping do
  context 'Ping' do
    let(:ping) do
      Frame::Ping.new(
        opaque: 'deadbeef'
      )
    end

    it 'should encode' do
      expect(ping.to_binary_s).to eq "\x00\x00\x08\x06\x00\x00\x00\x00\x00\x64\x65\x61\x64\x62\x65\x65\x66".b
    end

    it 'should decode' do
      expect(Frame::Ping.read("\x00\x00\x08\x06\x00\x00\x00\x00\x00\x64\x65\x61\x64\x62\x65\x65\x66".b)).to eq ping
    end
  end
end
