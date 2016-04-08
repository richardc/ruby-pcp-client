require 'eventmachine'
require 'faye/websocket'
require 'pcp/message'
require 'logger'

# So EventMachine when you specify :verify_peer => true in the TLS
# options decides what that means is it should just fire off a
# #ssl_verify_peer(cert) on the Connection object; which is expected
# to be user-supplied.  In this case the user is
# Faye::Websocket::Client::Connection, so we monkey-patch it to have a
# #ssl_verify_peer method.

module Faye
  class WebSocket
    class Client
      module Connection
        def ssl_verify_peer(cert)
          # The :@socket_tls instance variable of
          # Faye::Websocket::Client is passed to tls_start, so we can
          # get parameters from there.
          start_tls_options = parent.instance_variable_get(:@socket_tls)
          logger = start_tls_options[:xxx_logger]
          logger.debug { [:ssl_verify_peer] }

          peer_cert = OpenSSL::X509::Certificate.new cert

          hostname = start_tls_options[:xxx_hostname]
          if !OpenSSL::SSL.verify_certificate_identity(peer_cert, hostname)
            logger.error { [:ssl_verify_peer, :fail,
                           "Certificate presented does not match '#{hostname}'"] }
            return false
          end

          ssl_ca_cert = start_tls_options[:xxx_ssl_ca_cert]
          cert_store = OpenSSL::X509::Store.new
          cert_store.add_file ssl_ca_cert

          if !cert_store.verify(peer_cert)
            logger.error { [:ssl_verify_peer, :ca_verify_failed,
                            "Peer certificate not verified by ca"] }
            return false
          end

          logger.debug { [:ssl_verify_peer, :success] }
          return true
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
      if @connection
        # We close over so much, we really just need to say no for now
        raise "Can only connect once per client"
      end

      mutex = Mutex.new
      associated_cv = ConditionVariable.new

      @logger.debug { [:connect, :scheduling] }
      EM.next_tick do
        @logger.debug { [:connect, @server] }

        start_tls_options = {
          :ssl_version => ["TLSv1", "TLSv1_1", "TLSv1_2"],
          :private_key_file => @ssl_key,
          :cert_chain_file => @ssl_cert,
          :verify_peer => true,
          :fail_if_no_peer_cert => true,
          # side-channeled properties we want around during ssl
          # verification are prefixed with xxx_.
          :xxx_logger => @logger,
          :xxx_ssl_ca_cert => @ssl_ca_cert,
          :xxx_hostname => URI.parse(@server).host,
        }

        @connection = Faye::WebSocket::Client.new(@server, nil, {:tls => start_tls_options})

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
      end

      if !EM.reactor_running?
        @logger.debug { [:no_eventmachine_reactor,
                         "Eventmachine reactor is not running" ] }
        return nil
      end

      if EM.reactor_thread?
        # Because we use a condition variable to signal this thread
        # from the reactor thread to provide an imperative interface,
        # they cannot be the same thread.  We might associate later,
        # we just can't wait on ourselves from here.
        @logger.debug { [:connection_cannot_wait,
                        "Cannot wait on a connection if we are in the same thread as the reactor" ] }
        return nil
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
      EM.next_tick do
        @logger.debug { [:send, message] }
        message[:sender] = identity
        @connection.send(message.encode)
      end
    end

    # Disconnect the client
    # @api public
    # @return unused
    def close
      EM.next_tick do
        @logger.debug { [:close] }
        @connection.close
      end
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
