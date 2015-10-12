require 'json'
require 'securerandom'
require 'time'

module PCP
  class Message
    attr_reader :envelope

    def initialize(envelope = {})
      default_envelope = {:id => SecureRandom.uuid}
      @envelope = default_envelope.merge(envelope)
      @chunks = ['', '']
    end

    def expires(seconds)
      @envelope[:expires] = (Time.now + seconds).utc.iso8601
      self
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

    def self.decode(bytes = '')
      message = Message.new
      (version, rest) = bytes.unpack('Ca*')

      unless version == 1
        raise "Can only handle type 1 messages"
      end

      while rest.bytesize > 0
        (type, size, rest) = rest.unpack('CNa*')
        (body, rest) = rest.unpack("a#{size}a*")

        if type == 1
          envelope = JSON.parse(body)
          envelope.each do |k,v|
            message[k.to_sym] = v
          end
        else
          message.instance_variable_get(:@chunks)[type - 2] = body
        end
      end

      message
    end

    def encode
      chunks = []

      @chunks.each_index do |i|
        chunks << frame_chunk(i + 2, @chunks[i])
      end

      ["\x01", frame_chunk(1, envelope.to_json), chunks].flatten.join('')
    end

    private

    def frame_chunk(type, body)
      [type, body.bytesize, body].pack('CNa*')
    end
  end
end
