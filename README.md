pcp-client
==========

This library provides a client library for the [Puppet Communications Protocol](https://github.com/puppetlabs/pcp-specifications) wire protocol.


Basic Usage
==========

```sh
gem install pcp-client
```

To connect to a broker and send and receive messages:

```ruby
require 'pcp/client'

# Start an eventmachine main loop
Thread.new { EM.run }

client = PCP::Client.new({:server => 'wss://localhost:8142/pcp',
                          :ssl_key => 'test-resources/ssl/private_keys/client01.example.com.pem',
                          :ssl_cert => 'test-resources/ssl/certs/client01.example.com.pem'})

client.on_message = proc do |message|
  puts "Get message: #{message.inspect}"
end

client.connect

message = PCP::Message.new({:message_type => 'example/ping',
                            :targets => ['pcp://*/example-agent']})

client.send(message)

# Hang around and see what responses we get back
sleep(10)
end
```


A matching agent that would respond to this may look like this:

```ruby
require 'pcp/client'

# Start an eventmachine main loop
Thread.new { EM.run }

client = PCP::Client.new({:server => 'wss://localhost:8142/pcp',
                          :ssl_key => 'test-resources/ssl/private_keys/client02.example.com.pem',
                          :ssl_cert => 'test-resources/ssl/certs/client02.example.com.pem',
                          :type => 'example-agent'})

# Set up on_message handler
client.on_message = proc do |message|
  puts "Got message #{message.inspect}"
  if message[:message_type] == 'example/ping'
    response = PCP::Message.new({:message_type => 'example/pong',
                                 :targets => [message[:sender]]})
    client.send(response)
  end
end

# connect
client.connect

# wait forever for work
loop do end
```

There's a more extended example of this which makes more use of
PCP/PXP features in bin/pcp-ping.

Testing
=======

```sh
bundle install
bundle exec rspec spec
```

Support
=======

To report issues please use the [Puppet Communications Protocol project on
JIRA](https://tickets.puppetlabs.com/browse/PCP) with the component `ruby-pcp-client`.
