require 'sidekiq'
require "magic_pipe/senders/base"

module MagicPipe
  module Senders
    class Async < Base
      class Worker
        include Sidekiq::Worker

        def perform(decomposed_object, topic, time, client_name)
          client = MagicPipe.lookup_client(client_name)
          object = client.loader.load(decomposed_object)
          codec = client.codec

          metadata = {
            topic: topic,
            producer: client.config.producer_name,
            time: time.to_i,
            mime: codec::TYPE
          }

          envelope = Envelope.new(
            body: object,
            **metadata
          )

          payload = codec.new(envelope).encode
          client.transport.submit(payload, metadata)

          track_success(client, topic)
        rescue => e
          track_failure(client, topic)
          raise e
        end

        def track_success(client, topic)
          client.metrics.increment(
            "magic_pipe.senders.async.mgs_sent",
            tags: ["topic:#{topic}"]
          )
        end

        def track_failure(client, topic)
          client.metrics.increment(
            "magic_pipe.senders.async.failure",
            tags: ["topic:#{topic}"]
          )
        end
      end


      SETTINGS = {
        "class" => Worker,
        "retry" => true
      }

      def call
        enqueue
      end

      def enqueue
        options = SETTINGS.merge({
          "queue" => queue_name,
          "args" => [
            decomposed_object,
            @topic,
            @time.to_i,
            @config.client_name
          ]
        })
        Sidekiq::Client.push(options)
      end


      private


      def queue_name
        @config.async_transport_options[:queue]
      end

      def decomposed_object
        loader = MagicPipe::Loaders.lookup(@config.loader)
        loader.new(@object, @wrapper).decompose
      end
    end
  end
end
