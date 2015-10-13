require 'faye/websocket'
require 'pcp/message'

module PCP
  class Client
    attr_accessor :identity

    def initialize(params = {})
      @params = params
      @connection = nil
      @identity = make_identity
      @associated = false
    end

    def connect(seconds)
      mutex = Mutex.new
      associated_cv = ConditionVariable.new

      server = @params[:server] || 'wss://localhost:8142/pcp'
      #p [:connect, server]
      @connection = Faye::WebSocket::Client.new(server, nil, {:tls => {:private_key_file => @params[:key],
                                                                       :cert_chain_file => @params[:cert]}})

      @connection.on :open do |event|
        #p [:open]
        send(associate_request)
      end

      @connection.on :message do |event|
        #p [:message, event.data]
        bytes = event.data.pack('C*')
        message = ::PCP::Message.decode(bytes)

        if message[:message_type] == 'http://puppetlabs.com/associate_response'
          mutex.synchronize do
            @associated = JSON.load(message.data)["success"]
            associated_cv.signal
          end
        elsif block_given?
          yield message
        end
      end

      @connection.on :close do |event|
        #p [:close, event.code, event.reason]
        @associated = false
      end

      @connection.on :error do |event|
        #p [:error, event]
        @associated = false
      end

      begin
        Timeout::timeout(seconds) do
          mutex.synchronize do
            associated_cv.wait(mutex)
            return @associated
          end
        end
      rescue Timeout::Error
        return false
      end
    end

    def associated?
      @associated
    end

    def send(message)
      #p [:send, message]
      message[:sender] = @identity
      encoded = message.encode
      bytes = encoded.bytes.to_a
      @connection.send(bytes)
    end

    private

    def get_common_name(file)
      raw = File.read file
      cert = OpenSSL::X509::Certificate.new raw
      cert.subject.to_a.assoc('CN')[1]
    end

    def make_identity
      cn = get_common_name(@params[:cert])
      type = @params[:type] || "ruby-pcp-client-#{$$}"
      "pcp://#{cn}/#{type}"
    end

    def associate_request
      #p [:associate_request, @identity]
      Message.new({:message_type => 'http://puppetlabs.com/associate_request',
                   :sender => @identity,
                   :targets => ['pcp:///server']}).expires(3)
    end
  end
end
