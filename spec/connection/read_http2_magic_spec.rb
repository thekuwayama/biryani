require_relative '../spec_helper'

RSpec.describe Connection do
  context 'read_http2_magic' do
    let(:io1) do
      StringIO.new("PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n")
    end
    it 'should read' do
      expect { Connection.read_http2_magic(io1) }.not_to raise_error
    end

    let(:io2) do
      StringIO.new("PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n\x00xff")
    end
    it 'should read' do
      expect { Connection.read_http2_magic(io2) }.not_to raise_error
    end

    let(:io3) do
      StringIO.new("\x00xffPRI * HTTP/2.0\r\n\r\nSM\r\n\r\n")
    end
    it 'should not read' do
      expect { Connection.read_http2_magic(io3) }.to raise_error(RuntimeError)
    end
  end
end
