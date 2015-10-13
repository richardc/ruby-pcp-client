require 'pcp/client'

RSpec.describe PCP::Client do
  context 'constructor' do
    it 'should derive an identity from the cn and type' do
      expect(described_class.new(:cert => 'test-resources/ssl/certs/client01.example.com.pem',
                                 :type => 'rspec').identity).to eq("pcp://client01.example.com/rspec")
      expect(described_class.new(:cert => 'test-resources/ssl/certs/client02.example.com.pem').identity).to eq("pcp://client02.example.com/ruby-pcp-client-#{$$}")
    end
  end

  context '#get_common_name' do
    it 'should extract the common name from a cert in a file' do
      expect(described_class.new.send(:get_common_name, 'test-resources/ssl/certs/client01.example.com.pem')).to eq('client01.example.com')
    end
  end
end
