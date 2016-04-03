require 'eventmachine'
require 'faye/websocket'
require 'pcp/message'
require 'logger'

## evil, horrid, state inducing monkey patch of hell

# So EventMachine when you specify :verify_peer => true in the TLS
# options decides what that means is it should just fire off a
# #ssl_verify_peer(cert) on the Connection object; which is expected
# to be user-supplied.

# I guess this is eventmachine's attempt to get out of
# the business of dealing with ssl certificates

# To get us into the business of being able to verify the ssl cert,
# we're monkey-patching Faye::Websocket::Client::Connection to define
# the ssl_verify_peer method, so we can do the verification we need
# to do.
module Faye
  class WebSocket
    class Client
      module Connection
        def ssl_verify_peer(cert_text)
          ca_cert_file = parent.instance_variable_get(:@socket_tls)[:ssl_ca_cert]

          cert_store = OpenSSL::X509::Store.new
          cert_store.add_file ca_cert_file

          cert = OpenSSL::X509::Certificate.new cert_text

          if !cert_store.verify(cert)
            # Not trusted by the ca_cert
            return false
          end

          hostname = parent.instance_variable_get(:@socket_tls)[:hostname]

          # Check the CN matched the hostname we extracted from the URI
          # TODO: for extra credit, look at the Subject-Alternate-Names
          cert.subject.to_a.assoc('CN')[1] == hostname
        end
      end
    end
  end
end

module PCP
  # Manages a client connection to a pcp broker
  class Client
    # Read the @identity property
    #
    # @api public
    # @return [String]
    attr_accessor :identity

    # Set a proc that will be used to handle messages
    #
    # @api public
    # @return [Proc]
    attr_accessor :on_message

    # Construct a new disconnected client
    #
    # @api public
    # @param params [Hash<Symbol,Object>]
    # @return a new client
    def initialize(params = {})
      @server = params[:server] || 'wss://localhost:8142/pcp'
      @ssl_key = params[:ssl_key]
      @ssl_cert = params[:ssl_cert]
      @ssl_ca_cert = params[:ssl_ca_cert]
      @logger = params[:logger] || Logger.new(STDOUT)
      @logger.level = params[:loglevel] || Logger::WARN
      @connection = nil
      type = params[:type] || "ruby-pcp-client-#{$$}"
      @identity = make_identity(@ssl_cert, type)
      @on_message = params[:on_message]
      @associated = false
    end

    # Connect to the server
    #
    # @api public
    # @param seconds [Numeric]
    # @return [true,false,nil]
    def connect(seconds = 0)
      unless EM.reactor_running?
        raise "An Eventmachine reactor needs to be running"
      end

      if EM.reactor_thread?
        # Because we use a condition variable to signal this thread
        # from the reactor thread to provide an imperative interface,
        # they cannot be the same thread
        raise "Cannot be run on the same thread as the reactor"
      end

      if @connection
        # We close over so much, we really just need to say no for now
        raise "Can only connect once per client"
      end

      mutex = Mutex.new
      associated_cv = ConditionVariable.new

      @logger.debug { [:connect, @server] }

      @connection = Faye::WebSocket::Client.new(@server, nil, {:tls => {:private_key_file => @ssl_key,
                                                                        :cert_chain_file => @ssl_cert,
                                                                        # XXX this several forms of evil. see comment in the Faye monkeypatch earlier
                                                                        :ssl_ca_cert => @ssl_ca_cert,
                                                                        :verify_peer => true,
                                                                        :fail_if_no_peer_cert => true,
                                                                        :hostname => URI.parse(@server).host,
                                                                        :ssl_version => ["TLSv1_2"]}})

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

    # Is the client associated with the server
    #
    # @api public
    # @return [true,false]
    def associated?
      @associated
    end

    # Send a message to the server
    #
    # @api public
    # @param message [PCP::Message]
    # @return unused
    def send(message)
      @logger.debug { [:send, message] }
      message[:sender] = identity
      @connection.send(message.encode)
    end

    private

    # Get the common name from an X509 certficate in file
    #
    # @api private
    # @param [String] file
    # @return [String]
    def get_common_name(file)
      raw = File.read file
      cert = OpenSSL::X509::Certificate.new raw
      cert.subject.to_a.assoc('CN')[1]
    end

    # Make the PCP Uri for this client
    #
    # @api private
    # @param cert [String]
    # @param type [String]
    # @return [String]
    def make_identity(cert, type)
      cn = get_common_name(cert)
      "pcp://#{cn}/#{type}"
    end

    # Make an association request message for this client
    #
    # @api private
    # @return [PCP::Message]
    def associate_request
      Message.new({:message_type => 'http://puppetlabs.com/associate_request',
                   :sender => @identity,
                   :targets => ['pcp:///server']}).expires(3)
    end
  end
end
