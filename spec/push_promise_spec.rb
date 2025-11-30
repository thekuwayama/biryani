require_relative 'spec_helper'

RSpec.describe Frame::PushPromise do
  context do
    let(:push_promise1) do
      Frame::PushPromise.new(true, 10, 12, 'this is dummy', 'Howdy!')
    end
    it 'should encode' do
      expect(push_promise1.to_binary_s).to eq "\x00\x00\x18\x05\x0c\x00\x00\x00\x0a\x06\x00\x00\x00\x0c\x74\x68\x69\x73\x20\x69\x73\x20\x64\x75\x6d\x6d\x79\x48\x6f\x77\x64\x79\x21".b
    end

    let(:push_promise2) do
      Frame::PushPromise.read("\x00\x00\x18\x05\x0c\x00\x00\x00\x0a\x06\x00\x00\x00\x0c\x74\x68\x69\x73\x20\x69\x73\x20\x64\x75\x6d\x6d\x79\x48\x6f\x77\x64\x79\x21".b)
    end
    it 'should decode' do
      expect(push_promise2.f_type).to eq FrameType::PUSH_PROMISE
      expect(push_promise2.padded?).to eq true
      expect(push_promise2.stream_id).to eq 10
      expect(push_promise2.promised_stream_id).to eq 12
      expect(push_promise2.fragment).to eq 'this is dummy'
      expect(push_promise2.padding).to eq 'Howdy!'
    end
  end
end
