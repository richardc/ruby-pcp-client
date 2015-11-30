require 'rschema'

module PCP
  # Definitions of RSchema schemas for protocol definitions
  module Protocol
    # A [String] that represents a time according to ISO8601
    ISO8601 = RSchema.schema do
      predicate do |t|
        begin
          t.is_a?(String) && Time.parse(t)
        rescue ArgumentError
          # Time.parse raises an ArgumentError if the time isn't parsable
          false
        end
      end
    end

    # A [String] that is a message id
    MessageId = RSchema.schema do
      predicate do |id|
        id.is_a?(String) && id.match(%r{^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$})
      end
    end

    # A [String] that is a PCP uri
    Uri = RSchema.schema do
      predicate do |uri|
        uri.is_a?(String) && uri.match(%r{^pcp://([^/]*)/[^/]+$})
      end
    end

    # A [Hash] that complies to the properties of an Envelope
    Envelope = RSchema.schema do
      {
        :id => MessageId,
        optional(:'in-reply-to') => MessageId,
        :sender => Uri,
        :targets => [Uri],
        :message_type => String,
        :expires => ISO8601,
        optional(:destination_report) => boolean,
      }
    end
  end
end
