require_relative 'spec_helper'

RSpec.describe Frame::Continuation do
  context 'Continuation' do
    let(:continuation1) do
      Frame::Continuation.new(
        stream_id: 50,
        fragment: ''
      )
    end

    let(:continuation2) do
      Frame::Continuation.new(
        stream_id: 50,
        fragment: 'this is dummy'
      )
    end

    it 'should encode' do
      expect(continuation1.to_binary_s).to eq "\x00\x00\x00\x09\x00\x00\x00\x00\x32".b
      expect(continuation2.to_binary_s).to eq "\x00\x00\x0d\x09\x00\x00\x00\x00\x32\x74\x68\x69\x73\x20\x69\x73\x20\x64\x75\x6d\x6d\x79".b
    end

    it 'should decode' do
      expect(Frame::Continuation.read("\x00\x00\x00\x09\x00\x00\x00\x00\x32".b)).to eq continuation1
      expect(Frame::Continuation.read("\x00\x00\x0d\x09\x00\x00\x00\x00\x32\x74\x68\x69\x73\x20\x69\x73\x20\x64\x75\x6d\x6d\x79".b)).to eq continuation2
    end
  end
end
