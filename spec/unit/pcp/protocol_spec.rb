require 'pcp/protocol'

RSpec.describe PCP::Protocol do
  context 'ISO8601' do
    it 'should match' do
      expect(RSchema.validate(PCP::Protocol::ISO8601, '2015-11-13T12:06:31.031Z')).to eq(true)
      expect(RSchema.validate(PCP::Protocol::ISO8601, '')).to eq(false)
    end
  end

  context 'MessageId' do
    it 'should match' do
      expect(RSchema.validate(PCP::Protocol::MessageId, '6eeca275-e5d7-438c-b431-658f78f29d3e')).to eq(true)
      expect(RSchema.validate(PCP::Protocol::MessageId, '42')).to eq(false)
    end
  end

  context 'Uri' do
    it 'should match good uris' do
      expect(RSchema.validate(PCP::Protocol::Uri, 'pcp:///server')).to eq(true)
      expect(RSchema.validate(PCP::Protocol::Uri, 'pcp://localhost/server')).to eq(true)
      expect(RSchema.validate(PCP::Protocol::Uri, 'pcp:///server/slash')).to eq(false)
      expect(RSchema.validate(PCP::Protocol::Uri, 'pcp://localhost/slash/slash')).to eq(false)
      expect(RSchema.validate(PCP::Protocol::Uri, 'cth://localhost/slash')).to eq(false)
    end
  end

  context 'Envelope' do
    let(:envelope) do
      {
        :id => '6eeca275-e5d7-438c-b431-658f78f29d3e',
        :sender => 'pcp://client.example.com/rspec',
        :targets => ['pcp:///server'],
        :message_type => 'example',
        :expires => '2015-11-13T12:06:31.031Z'
      }
    end

    it 'should match' do
      expect(RSchema.validate(PCP::Protocol::Envelope, envelope)).to eq(true)
    end

    it 'should allow optional :in-reply-to' do
      expect(RSchema.validate(PCP::Protocol::Envelope,
                              envelope.merge({:'in-reply-to' => '5e5b8281-9315-43b4-9343-087762ccc51f'}))).to eq(true)
    end

    it 'should allow optional :destination_report' do
      expect(RSchema.validate(PCP::Protocol::Envelope,
                              envelope.merge({:'destination_report' => true}))).to eq(true)
    end


    it 'should reject with missing sender' do
      expect(RSchema.validate(PCP::Protocol::Envelope,
                              envelope.reject { |k,v| k == :sender })).to eq(false)
    end

    it 'should reject with invalid sender' do
      expect(RSchema.validate(PCP::Protocol::Envelope,
                              envelope.merge({:sender => 'http://example.com/not/this'}))).to eq(false)
    end

    it 'should reject with invalid targets' do
      expect(RSchema.validate(PCP::Protocol::Envelope,
                              envelope.merge({:targets => ['pcp://example.com/too/many/slashes']}))).to eq(false)
    end
  end
end
