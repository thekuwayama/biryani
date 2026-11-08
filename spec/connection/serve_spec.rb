require_relative '../spec_helper'

RSpec.describe Connection do
  context 'serve' do
    let(:conn) do
      Connection.new(do_nothing_proc)
    end

    let(:reset) do
      io = StringIO.new
      allow(io).to receive(:read).and_raise(Errno::ECONNRESET)
      allow(io).to receive(:close_write).and_raise(Errno::EPIPE)
      io
    end
    it 'should not raise when the peer resets the connection' do
      expect { expect { conn.serve(reset) }.not_to output.to_stdout }.not_to raise_error
    end

    let(:broken_pipe) do
      io = StringIO.new("\x00\xffPRI * HTTP/2.0\r\n\r\nSM\r\n\r\n".b)
      allow(io).to receive(:write).and_raise(Errno::EPIPE)
      allow(io).to receive(:close_write).and_raise(Errno::EPIPE)
      io
    end
    it 'should not raise when the peer has closed the connection' do
      expect { expect { conn.serve(broken_pipe) }.not_to output.to_stdout }.not_to raise_error
    end

    let(:internal_error) do
      io = StringIO.new
      allow(io).to receive(:read).and_raise(StandardError)
      allow(io).to receive(:write).and_raise(Errno::EPIPE)
      allow(io).to receive(:close_write).and_raise(Errno::EPIPE)
      io
    end
    it 'should not raise when sending GOAWAY to the closed peer' do
      expect { expect { conn.serve(internal_error) }.to output.to_stdout }.not_to raise_error
    end
  end
end
