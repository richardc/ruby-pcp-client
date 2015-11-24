require 'eventmachine-le'
require 'faye/websocket'
require 'pcp/message'
require 'logger'

module PCP
  class Client
    attr_accessor :identity

    def initialize(params = {})
      @server = params[:server] || 'wss://localhost:8142/pcp'
      @ssl_key = params[:ssl_key]
      @ssl_cert = params[:ssl_cert]
      @logger = Logger.new(STDOUT)
      @logger.level = params[:loglevel] || Logger::WARN
      @connection = nil
      type = params[:type] || "ruby-pcp-client-#{$$}"
      @identity = make_identity(@ssl_cert, type)
      @on_message = params[:on_message]
      @associated = false
    end

    def connect(seconds = 0)
      mutex = Mutex.new
      associated_cv = ConditionVariable.new

      @logger.debug { [:connect, @server] }
      @connection = Faye::WebSocket::Client.new(@server, nil, {:tls => {:private_key_file => @ssl_key,
                                                                        :cert_chain_file => @ssl_cert,
                                                                        :ssl_version => :TLSv1}})

      @connection.on :open do |event|
        begin
          @logger.info { [:open] }
          send(associate_request)
        rescue Exception => e
          @logger.error { [:open_exception, e] }
        end
      end

      @connection.on :message do |event|
        begin
          message = ::PCP::Message.new(event.data)
          @logger.debug { [:message, :decoded, message] }

          if message[:message_type] == 'http://puppetlabs.com/associate_response'
            mutex.synchronize do
              @associated = JSON.load(message.data)["success"]
              associated_cv.signal
            end
          elsif @on_message
            @on_message.call(message)
          end
        rescue Exception => e
          @logger.error { [:message_exception, e] }
        end
      end

      @connection.on :close do |event|
        begin
          @logger.info { [:close, event.code, event.reason] }
          mutex.synchronize do
            @associated = false
            associated_cv.signal
          end
        rescue Exception => e
          @logger.error { [:close_exception, e] }
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

    def make_identity(cert, type)
      cn = get_common_name(cert)
      "pcp://#{cn}/#{type}"
    end

    def associate_request
      Message.new({:message_type => 'http://puppetlabs.com/associate_request',
                   :sender => @identity,
                   :targets => ['pcp:///server']}).expires(3)
    end
  end
end
