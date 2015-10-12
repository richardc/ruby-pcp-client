module PCP
  class Message
    def initialize()
      @version = 1
      @envelope = {}
      @chunks = []
    end

    def self.decode(bytes = [])
      message = Message.new
      message
    end

    def encode
      []
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
  end
end
