require 'json'

module PCP
  class Message
    def initialize()
      @envelope = {}
      @chunks = ['', '']
    end

    # Envelope interaction when used as a hash
    def []=(key, value)
      @envelope[key] = value
    end

    def [](key)
      @envelope[key]
    end

    # Data chunk interaction
    def data
      @chunks[0]
    end

    def data=(value)
      @chunks[0] = value
    end

    # Debug chunk interaction
    def debug
      @chunks[1]
    end

    def debug=(value)
      @chunks[1] = value
    end

    def self.decode(bytes = [])
      message = Message.new
      message
    end

    def encode
      chunks = []

      @chunks.each_index do |i|
        chunks << frame_chunk(i + 2, @chunks[i])
      end

      ["\x01", frame_chunk(1, @envelope.to_json), chunks].flatten.join('')
    end

    private
    def frame_chunk(type, body)
      [type, body.bytesize, body].pack('CNa*')
    end
  end
end
