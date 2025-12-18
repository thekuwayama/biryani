require_relative '../spec_helper'

RSpec.describe Connection do
  context 'handle_connection_window_update' do
    let(:window_update) do
      Frame::WindowUpdate.new(0, 1000)
    end
    let(:send_window) do
      Window.new
    end
    it 'should handle' do
      expect { Connection.handle_connection_window_update(window_update, send_window) }.not_to raise_error
      expect(send_window.length).to eq 2**16 - 1 + 1000
    end
  end
end
