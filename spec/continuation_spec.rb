require_relative 'spec_helper'

RSpec.describe Frame::Continuation do
  context do
    let(:continuation1) do
      Frame::Continuation.new(false, 50, '')
    end
    it 'should encode' do
      expect(continuation1.to_binary_s).to eq "\x00\x00\x00\x09\x00\x00\x00\x00\x32".b
    end

    let(:continuation2) do
      Frame::Continuation.new(false, 50, 'this is dummy')
    end
    it 'should encode' do
      expect(continuation2.to_binary_s).to eq "\x00\x00\x0d\x09\x00\x00\x00\x00\x32\x74\x68\x69\x73\x20\x69\x73\x20\x64\x75\x6d\x6d\x79".b
    end

    let(:continuation3) do
      Frame::Continuation.read("\x00\x00\x00\x09\x00\x00\x00\x00\x32".b)
    end
    it 'should decode' do
      expect(continuation3.f_type).to eq FrameType::CONTINUATION
      expect(continuation3.end_headers?).to eq false
      expect(continuation3.stream_id).to eq 50
      expect(continuation3.fragment).to eq ''
    end

    let(:continuation4) do
      Frame::Continuation.read("\x00\x00\x0d\x09\x00\x00\x00\x00\x32\x74\x68\x69\x73\x20\x69\x73\x20\x64\x75\x6d\x6d\x79".b)
    end
    it 'should decode' do
      expect(continuation4.f_type).to eq FrameType::CONTINUATION
      expect(continuation4.end_headers?).to eq false
      expect(continuation4.stream_id).to eq 50
      expect(continuation4.fragment).to eq 'this is dummy'
    end
  end
end
