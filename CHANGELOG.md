## 0.4.0

- [PCP-366](https://tickets.puppetlabs.com/browse/PCP-366) New mandatory `:ssl_ca_cert`
  parameter for strict ssl validation.

## 0.3.1

- [PCP-329](https://tickets.puppetlabs.com/browse/PCP-361) Wrapped eventmachine
  interactions in `EM.next_tick` to avoid `EventMachine::ConnectionNotBound`
  exceptions.

## 0.3.0

- [PCP-361](https://tickets.puppetlabs.com/browse/PCP-361) Added
  ::PCP::Client#close method, to explicitly close the connection
- [PCP-179](https://tickets.puppetlabs.com/browse/PCP-179) Now depends on
  eventmachine 1.2 rather than eventmachine-le (1.2 absorbed the feature we
  needed from eventmachine-le).

## 0.2.0

- Added option parsing to bin/pcp-ping example
- [PCP-253](https://tickets.puppetlabs.com/browse/PCP-253) Formalised
  the use of eventmachine a little more to reflect the necessity to run
  the reactor in its own Thread
- [PCP-300](http://tickets.puppetlabs.com/browse/PCP-300) Added :logger
  parameter to ::PCP::Client constructor to allow a Logger instance to be
  supplied, and ::PCP::SimpleLogger added to keep log messages in memory.

## 0.1.0

Initial public release.
