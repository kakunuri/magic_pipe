require "base64"

RSpec.describe MagicPipe::Transports::Https do
  let(:base_url) { "https://localhost:8080/test" }
  let(:basic_auth_user) { "test-token" }
  let(:auth_header) { "Basic " + Base64.strict_encode64("#{basic_auth_user}:x") }
  let(:https_options) do
    {
      url: base_url,
      basic_auth: "#{basic_auth_user}:x",
    }
  end

  let(:config) do
    MagicPipe::Config.new do |c|
      c.codec = :yaml
      c.transport = :https

      c.https_transport_options = https_options
    end
  end

  let(:metrics) { MagicPipe::Metrics.new(config) }

  subject do
    described_class.new(config, metrics)
  end

  describe "the faraday connection" do
    let(:conn) { subject.conn}

    it "is configured with the right URL" do
      expect(conn.url_prefix).to eq URI(base_url)
    end

    it "is configured with the right headers" do
      expect(conn.headers["Content-Type"]).to eq "application/x-yaml"
      expect(conn.headers["User-Agent"]).to match(
        %r{\AMagicPipe v[\d\.]+ \(Faraday v[\d\.]+, Typhoeus v[\d\.]+\)\z}
      )
    end
  end

  describe "submit" do
    let(:payload) { "an encoded payload" }
    let(:metadata) do
      {
        topic: "marsupials",
        producer: "Mr. Koala",
        time: 123123123,
        mime: "none"
      }
    end


    def perform
      subject.submit!(payload, metadata)
    end


    def self.it_submits_a_request_with_the_correct_data
      it "submits a request with the correct data" do
        stub_request(:post, target_url).with(
          body: payload,
          headers: {
            "Content-Type" => "application/x-yaml",
            "Authorization" => auth_header,
            "X-MagicPipe-Sent-At" => 123123123,
            "X-MagicPipe-Topic" => "marsupials",
            "X-MagicPipe-Producer" => "Mr. Koala"
          }
        )

        perform
      end
    end


    describe "without a custom path" do
      let(:target_url) { base_url }

      it_submits_a_request_with_the_correct_data
    end


    describe "when using a dynamic sub path" do
      let(:https_options) do
        super().merge(
          dynamic_path_builder: -> (topic) { topic + "-" + topic + "/foo" }
        )
      end

      let(:target_url) { base_url + "/marsupials-marsupials/foo" }

      it_submits_a_request_with_the_correct_data
    end


    describe "when using a dynamic full path" do
      let(:https_options) do
        super().merge(
          dynamic_path_builder: -> (topic) { "/" + topic + "-" + topic + "/foo" }
        )
      end

      let(:target_url) { base_url.sub("/test", "/marsupials-marsupials/foo") }

      it_submits_a_request_with_the_correct_data
    end

    describe "when using a dynamic `basic_auth`" do
      let(:target_url) { base_url }
      let(:https_options) do
        super().merge(
          basic_auth: -> (topic) { "test-#{topic}:foobar" }
        )
      end
      let(:auth_header) { "Basic " + Base64.strict_encode64("test-marsupials:foobar") }

      it_submits_a_request_with_the_correct_data
    end

    describe "when the HTTP request fails" do
      before do
        stub_request(:post, base_url).to_return(status: 504, body: "on, no!")
      end

      let(:error_msg) do
        "MagicPipe::Transports::Https couldn't submit message (HTTP response: status=504 body=\"on, no!\")"
      end

      it "raises an exception" do
        expect { perform }.to raise_error(
          MagicPipe::Transports::SubmitFailedError,
          error_msg
        )
      end

      specify "the exception returns the message with #to_s" do
        # This is important because some error trackers will call #to_s
        # instead of #message, for example NewRelic.
        error = nil

        begin
          perform
        rescue => e
          error = e
        end

        expect(error.to_s).to eq error_msg
      end
    end
  end
end
