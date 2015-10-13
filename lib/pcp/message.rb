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

    def self.decode(bytes = [])
      message = Message.new
      version = bytes.shift

      unless version == 1
        raise "Can only handle type 1 messages"
      end

      while bytes.size > 0
        type = bytes.shift
        size = bytes.take(4).pack('C*').unpack('N')[0]
        bytes = bytes.drop(4)

        body = bytes.take(size).pack('C*')
        bytes = bytes.drop(size)

        if type == 1
          envelope = JSON.parse(body)
          message.instance_variable_set(:@envelope, {})
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

      [1, frame_chunk(1, envelope.to_json), chunks].flatten
    end

    private

    def frame_chunk(type, body)
      size = [body.bytesize].pack('N').unpack('C*')
      [type, size, body.bytes.to_a].flatten
    end
  end
end
