module Biryani
  class Connection
    CONNECTION_PREFACE = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n".freeze
    CONNECTION_PREFACE_LENGTH = CONNECTION_PREFACE.length
    private_constant :CONNECTION_PREFACE, :CONNECTION_PREFACE_LENGTH

    # @param io [IO]
    def serve(io)
      self.class.read_http2_magic(io)

      _wport = Writer.new.loop
      # TODO: write Frame::Settings via wport

      loop do
        _frame = Frame.read(io)

        # TODO: handling frame & stream.new with wport
      end
    end

    # @param io [IO]
    def self.read_http2_magic(io)
      s = io.read(CONNECTION_PREFACE_LENGTH)
      abort 'protocol_error' if s != CONNECTION_PREFACE # TODO: send error
    end

    class Writer
      def initialize; end

      # @return [Ractor::Port]
      def loop
        Ractor.new do
          loop do
            io, f = Ractor.receive
            io.write(f) # TODO: check window
          end
        end
      end
    end
  end
end
