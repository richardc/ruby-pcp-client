require 'pcp/message'

RSpec.describe PCP::Message do
  # Use the same uuid in all tests - this from a fair dice roll
  let(:uuid) { '3790c4a2-dd71-41bf-bd6d-573779b38657' }

  before :each do
    allow(SecureRandom).to receive(:uuid).and_return(uuid)
  end

  context 'constructor' do
    it 'makes an object' do
      expect(described_class.new).to be_an_instance_of(described_class)
    end

    it 'sets up a default envelope' do
      expect(described_class.new.envelope).to eq({:id => uuid})
    end

    it 'merges arguments' do
      expect(described_class.new({:message_type => 'example/rspec'}).envelope).to eq({:id => uuid, :message_type => 'example/rspec'})
      expect(described_class.new({:id => 'rspec'}).envelope).to eq({:id => 'rspec'})
    end
  end

  context '#expires' do
    it 'sets the expiry in the envelope, returning a message' do
      expect(Time).to receive(:now).and_return(Time.at(0))
      expect(described_class.new.expires(3)[:expires]).to eq('1970-01-01T00:00:03Z')
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
      expect(message.envelope[:targets]).to eq(['pcp:///server'])
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
      encoded = [1,
                 1, 0, 0, 0, 2, 123, 125,
                 2, 0, 0, 0, 4, 116, 101, 115, 116,
                 3, 0, 0, 0, 0]
      allow(RSchema).to receive(:validate!).with(PCP::Protocol::Envelope, {})
      message = described_class.decode(encoded)
      expect(message.data).to eq('test')
      expect(message.envelope).to eq({})
    end
  end

  context '#encode' do
    it 'returns an array of bytes' do
      message = described_class.new
      message.data = 'test'
      expect(message).to receive(:envelope).and_return({}).twice
      allow(RSchema).to receive(:validate!).with(PCP::Protocol::Envelope, {})
      encoded = message.encode
      expect(encoded).to eq([1,
                             1, 0, 0, 0, 2, 123, 125,
                             2, 0, 0, 0, 4, 116, 101, 115, 116,
                             3, 0, 0, 0, 0])
    end
  end
end
