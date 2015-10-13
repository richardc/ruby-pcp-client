require 'pcp/client'

RSpec.describe PCP::Client do
  context 'constructor' do
    it 'should derive an identity from the cn and type' do
      client = described_class.new
      expect(described_class.new(:type => 'rspec').identity).to eq("pcp://client04.example.com/rspec")
      expect(described_class.new.identity).to eq("pcp://client04.example.com/ruby-pcp-client-#{$$}")
    end
  end
end
