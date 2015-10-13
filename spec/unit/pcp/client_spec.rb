require 'pcp/client'

RSpec.describe PCP::Client do
  context 'constructor' do
    it 'should derive an identity from the cn and type' do
      expect(described_class.new(:cert => 'test-resources/ssl/certs/client01.example.com.pem',
                                 :type => 'rspec').identity).to eq("pcp://client01.example.com/rspec")
      expect(described_class.new(:cert => 'test-resources/ssl/certs/client02.example.com.pem').identity).to eq("pcp://client02.example.com/ruby-pcp-client-#{$$}")
    end
  end
end
