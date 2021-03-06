RSpec.describe MagicPipe::Metrics do
  let(:statsd) { double("Statsd client", increment: nil) }
  let(:transport) { :sqs }

  let(:config) do
    MagicPipe::Config.new do |c|
      c.producer_name = "FooBar Test"
      c.client_name = :foo_bar
      c.loader = :custom_loader
      c.codec = :json
      c.transport = transport
      c.sender = :sync
      c.metrics_client = statsd
    end
  end

  subject { described_class.new(config) }

  describe "it responds to the statsd methods" do
    example "increment" do
      expect {
        subject.increment "fancy.metric.name", tags: ["foo:bar"]
      }.to_not raise_error
    end
  end


  describe "#increment" do
    it "forwards the message to the statsd client" do
      expect(statsd).to receive(:increment).with(
        "foo.bar",
        { tags: array_including("qwe:rty") }
      )

      subject.increment("foo.bar", tags: ["qwe:rty"])
    end


    describe "it augments the tags with the default tags" do
      specify "with custom tags" do
        expect(statsd).to receive(:increment).with(
          "foo.bar",
          {
            tags: [
              "producer:FooBar_Test",
              "pipe_instance:foo_bar",
              "loader:custom_loader",
              "codec:json",
              "transport:sqs",
              "sender:sync",
              "qwe:rty", # the explicitly passed one!
            ]
          }
        )

        subject.increment("foo.bar", tags: ["qwe:rty"])
      end

      specify "without extra tags" do
        expect(statsd).to receive(:increment).with(
          "foo.bar",
          {
            tags: [
              "producer:FooBar_Test",
              "pipe_instance:foo_bar",
              "loader:custom_loader",
              "codec:json",
              "transport:sqs",
              "sender:sync",
            ]
          }
        )

        subject.increment("foo.bar")
      end
    end


    describe "with multiple transports" do
      class MagicPipe::MyCustomTransport; end;
      let(:transport) { [:sqs, :log, MagicPipe::MyCustomTransport] }

      it "builds a composite transport tag" do
        expect(statsd).to receive(:increment).with(
          "foo.bar",
          { tags: array_including("transport:multi_sqs-log-MagicPipeMyCustomTransport") }
        )

        subject.increment("foo.bar")
      end
    end
  end
end
