require 'pcp/message'

RSpec.describe PCP::Message do
  context 'constructor' do
    it 'makes an object' do
      expect(described_class.new).to be_an_instance_of(described_class)
    end
  end

  context '#[]' do
    it 'fetches from @envelope' do
      message = described_class.new
      message.instance_variable_set(:@envelope, {:sender => 'pcp://localhost/test'})
      expect(message[:sender]).to eq('pcp://localhost/test')
    end
  end

  context '#[]=' do
    it 'updates @envelope' do
      message = described_class.new
      message[:targets] = ['pcp:///server']
      expect(message.instance_variable_get(:@envelope)).to eq({:targets => ['pcp:///server']})
    end
  end

  context '#data' do
    it 'fetches from @chunks' do
      message = described_class.new
      message.instance_variable_set(:@chunks, ['data', 'debug'])
      expect(message.data).to eq('data')
    end
  end

  context '#data=' do
    it 'updates @chunks' do
      message = described_class.new
      message.instance_variable_set(:@chunks, ['data', 'debug'])
      message.data = 'new-data'
      expect(message.instance_variable_get(:@chunks)).to eq(['new-data', 'debug'])
    end
  end

  context '#debug' do
    it 'fetches from @chunks' do
      message = described_class.new
      message.instance_variable_set(:@chunks, ['data', 'debug'])
      expect(message.debug).to eq('debug')
    end
  end

  context '#debug=' do
    it 'updates @chunks' do
      message = described_class.new
      message.instance_variable_set(:@chunks, ['data', 'debug'])
      message.debug = 'new-debug'
      expect(message.instance_variable_get(:@chunks)).to eq(['data', 'new-debug'])
    end
  end

  context '.decode' do
    it 'makes a message' do
      message = described_class.decode([1])
      expect(message).to be_an_instance_of(described_class)
    end
  end

  context '#encode' do
    it 'returns an array of bytes' do
      message = described_class.new
      message.data = 'test'
      encoded = message.encode
      expect(encoded).to eq("\x01" +
                            "\x01\x00\x00\x00\x02{}" +
                            "\x02\x00\x00\x00\x04test" +
                            "\x03\x00\x00\x00\x00")
    end
  end
end
