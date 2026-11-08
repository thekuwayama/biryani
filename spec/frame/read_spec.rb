require_relative '../spec_helper'

RSpec.describe Frame do
  context do
    let(:empty) do
      StringIO.new(''.b)
    end
    it 'should not read' do
      expect(Frame.read(empty)).to eq nil
    end

    let(:invalid_header) do
      StringIO.new("\x12\x34\x56\x00\x00".b)
    end
    it 'should not read' do
      expect(Frame.read(invalid_header)).to be_kind_of ConnectionError
    end

    let(:unknown) do
      StringIO.new("\x00\x00\x01\x0a\x01\x00\x00\x00\x01\xff".b)
    end
    it 'should read' do
      frame = Frame.read(unknown)
      expect(frame.f_type).to eq 0x0a
      expect(frame.flags).to eq 0x01
      expect(frame.stream_id).to eq 0x01
      expect(frame.payload).to eq "\xff".b
    end

    let(:reset) do
      io = StringIO.new
      allow(io).to receive(:read).and_raise(Errno::ECONNRESET)
      io
    end
    it 'should treat ECONNRESET as EOF' do
      expect(Frame.read(reset)).to eq nil
    end

    let(:truncated_payload) do
      StringIO.new("\x00\x00\x01\x0a\x01\x00\x00\x00\x01".b)
    end
    it 'should return PROTOCOL_ERROR for truncated payload' do
      obj = Frame.read(truncated_payload)
      expect(obj).to be_kind_of ConnectionError
      expect(obj.goaway(0).error_code).to eq ErrorCode::PROTOCOL_ERROR
    end
  end
end
