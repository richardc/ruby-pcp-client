require 'json'
require 'securerandom'
require 'time'
require 'pcp/protocol'

module PCP
  # Represent a message that can be sent via PCP::Client
  class Message
    # Read access to the @envelope property
    #
    # @api public
    # @return [Hash<Symbol,Object>]
    attr_reader :envelope

    # Construct a new message or decode one
    #
    # @api public
    # @param envelope_or_bytes [Hash<Symbol,Object>,Array<Integer>]
    #   When supplied a Hash it is taken as being a collection of
    #   envelope fields.
    #   When supplied an Array it is taken as being an array of
    #   byte values, a message in wire format.
    # @return a new object
    def initialize(envelope_or_bytes = {})
      @chunks = ['', '']

      case envelope_or_bytes
      when Array
        # it's bytes
        decode(envelope_or_bytes)
      when Hash
        # it's an envelope
        default_envelope = {:id => SecureRandom.uuid}
        @envelope = default_envelope.merge(envelope_or_bytes)
      else
        raise ArgumentError, "Unhandled type"
      end
    end

    # Set the expiry of the message
    #
    # @api public
    # @param seconds [Numeric]
    # @return the object itself
    def expires(seconds)
      @envelope[:expires] = (Time.now + seconds).utc.iso8601
      self
    end

    # Set an envelope field
    #
    # @api public
    # @param key [Symbol]
    # @param value
    # @return value
    def []=(key, value)
      @envelope[key] = value
    end

    # Get an envelope field
    #
    # @api public
    # @param key [Symbol]
    # @return value associated with that key
    def [](key)
      @envelope[key]
    end

    # Get the content of the data chunk
    #
    # @api public
    # @return current content of the data chunk
    def data
      @chunks[0]
    end

    # Sets the content for the data chunk
    #
    # @api public
    # @param value
    # @return value
    def data=(value)
      @chunks[0] = value
    end

    # Get the content of the debug chunk
    #
    # @api public
    # @return current content of the debug chunk
    def debug
      @chunks[1]
    end

    # Sets the content for the debug chunk
    #
    # @api public
    # @param value
    # @return value
    def debug=(value)
      @chunks[1] = value
    end

    # Encodes the message as an array of byte values
    #
    # @api public
    # @return [Array<Integer>]
    def encode
      chunks = []

      @chunks.each_index do |i|
        chunks << frame_chunk(i + 2, @chunks[i])
      end

      RSchema.validate!(PCP::Protocol::Envelope, envelope)

      [1, frame_chunk(1, envelope.to_json), chunks].flatten
    end

    private

    # Decodes an array of bytes into the message
    #
    # @api private
    # @param bytes [Array<Integer>]
    # @return ignore
    def decode(bytes)
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
          parsed = JSON.parse(body)
          @envelope = {}
          parsed.each do |k,v|
            @envelope[k.to_sym] = v
          end
          RSchema.validate!(PCP::Protocol::Envelope, @envelope)
        else
          @chunks[type - 2] = body
        end
      end
    end

    # Frames a piece of data as a message chunk of given type
    #
    # @api private
    # @param type [Integer]
    # @param body [String]
    # @return [Array<Integer>]
    def frame_chunk(type, body)
      size = [body.bytesize].pack('N').unpack('C*')
      [type, size, body.bytes.to_a].flatten
    end
  end
end
