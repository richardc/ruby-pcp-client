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
