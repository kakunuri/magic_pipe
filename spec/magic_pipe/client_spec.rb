RSpec.describe MagicPipe::Client do
  let(:config) do
    MagicPipe::Config.new do |c|
      c.codec = :json
      c.transport = :https
      c.https_transport_options = {} # let the defaults apply
      c.sender = :sync
    end
  end

  subject { described_class.new(config) }

  describe "creation and configuration" do
    it "can access the configuration" do
      expect(subject.config).to eq config

      expect(subject.transport).to be_an_instance_of(MagicPipe::Transports::Https)

      expect(subject.codec).to eq MagicPipe::Codecs::Json
      expect(subject.sender).to eq MagicPipe::Senders::Sync
    end
  end

  describe "metrics" do
    subject { super().metrics }

    it "returns a Metrics object" do
      expect(subject).to be_a MagicPipe::Metrics
    end
  end

  describe "send_data" do
    xit "runs" do
    end
  end
end
