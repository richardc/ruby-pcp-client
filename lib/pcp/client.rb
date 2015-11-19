require 'eventmachine-le'
require 'faye/websocket'
require 'pcp/message'
require 'logger'

module PCP
  class Client
    attr_accessor :identity

    def initialize(params = {})
      @params = params
      @logger = Logger.new(STDOUT)
      @logger.level = params[:loglevel] || Logger::WARN
      @connection = nil
      @identity = make_identity
      @on_message = params[:on_message]
      @associated = false
    end

    def connect(seconds)
      mutex = Mutex.new
      associated_cv = ConditionVariable.new

      server = @params[:server] || 'wss://localhost:8142/pcp'
      @logger.debug { [:connect, server] }
      @connection = Faye::WebSocket::Client.new(server, nil, {:tls => {:private_key_file => @params[:key],
                                                                       :cert_chain_file => @params[:cert],
                                                                       :ssl_version => :TLSv1}})

      @connection.on :open do |event|
        @logger.info { [:open] }
        send(associate_request)
      end

      @connection.on :message do |event|
        message = ::PCP::Message.decode(event.data)
        @logger.debug { [:message, :decoded, message] }

        if message[:message_type] == 'http://puppetlabs.com/associate_response'
          mutex.synchronize do
            @associated = JSON.load(message.data)["success"]
            associated_cv.signal
          end
        elsif @on_message
          @on_message.call(message)
        end
      end

      @connection.on :close do |event|
        @logger.info { [:close, event.code, event.reason] }
        mutex.synchronize do
          @associated = false
          associated_cv.signal
        end
      end

      @connection.on :error do |event|
        @logger.error { [:error, event] }
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
        return nil
      end
    end

    def associated?
      @associated
    end

    def send(message)
      @logger.debug { [:send, message] }
      message[:sender] = identity
      @connection.send(message.encode)
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
