require_relative 'spec_helper'

RSpec.describe Frame::PushPromise do
  context 'PushPromise' do
    let(:push_promise) do
      Frame::PushPromise.new(
        padded: true,
        end_headers: true,
        stream_id: 10,
        promised_stream_id: 12,
        fragment: 'this is dummy',
        padding: 'Howdy!'
      )
    end

    it 'should encode' do
      expect(push_promise.to_binary_s).to eq "\x00\x00\x18\x05\x0c\x00\x00\x00\x0a\x06\x00\x00\x00\x0c\x74\x68\x69\x73\x20\x69\x73\x20\x64\x75\x6d\x6d\x79\x48\x6f\x77\x64\x79\x21".b
    end

    it 'should decode' do
      expect(Frame::PushPromise.read("\x00\x00\x18\x05\x0c\x00\x00\x00\x0a\x06\x00\x00\x00\x0c\x74\x68\x69\x73\x20\x69\x73\x20\x64\x75\x6d\x6d\x79\x48\x6f\x77\x64\x79\x21".b)).to eq push_promise
    end
  end
end
