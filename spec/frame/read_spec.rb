require_relative '../spec_helper'

RSpec.describe Frame do
  context do
    let(:empty) do
      StringIO.new(''.b)
    end
    it 'should not read' do
      expect(Frame.read(empty)).to be_kind_of ConnectionError
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
  end
end
