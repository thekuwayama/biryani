require_relative '../spec_helper'

RSpec.describe Connection do
  context 'handle_response' do
    let(:io) do
      StringIO.new
    end
    let(:res) do
      HTTP::Response.new(200, {}, 'OK')
    end
    let(:conn) do
      Connection.new(do_nothing_proc)
    end

    it 'should not send on a closed stream' do
      ctx = conn.instance_variable_get(:@streams_ctx).new_context(1, 65_535, 65_535)
      ctx.state_transition!(Frame::Headers.new(true, true, 1, nil, nil, 'this is dummy'.b, nil), :recv)
      ctx.state_transition!(Frame::RstStream.new(1, ErrorCode::CANCEL), :recv)
      conn.handle_response(io, res, 1)
      expect(io.string).to eq ''
    end

    it 'should not send on a nonexistent stream' do
      conn.handle_response(io, res, 1)
      expect(io.string).to eq ''
    end
  end
end
