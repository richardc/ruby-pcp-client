require 'logger'

# This logger just adds events to the @events property, so when you
# .inspect it you can see what was logged.
module PCP
  class SimpleLogger < ::Logger
    def initialize(*args)
      @events = []
    end

    def add(severity, message = nil, progname = nil)
      if message.nil?
        if block_given?
          message = yield
        else
          message = progname
        end
      end

      @events << {:when => Time.now.to_f,
                  :severity => severity,
                  :message => message}
    end
  end
end
