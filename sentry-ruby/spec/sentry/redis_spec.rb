require "spec_helper"

RSpec.describe Sentry::Redis do
  let(:redis) do
    Redis.new
  end

  context "with tracing enabled" do
    before do
      perform_basic_setup do |config|
        config.traces_sample_rate = 1.0
      end
    end

    context "calling Redis SET command" do
      let(:result) { redis.set("key", "value") }

      it "records the Redis call's span with command and key" do
        transaction = Sentry.start_transaction
        Sentry.get_current_scope.set_span(transaction)

        expect(result).to eq("OK")
        request_span = transaction.span_recorder.spans.last
        expect(request_span.op).to eq("db.redis.command")
        expect(request_span.start_timestamp).not_to be_nil
        expect(request_span.timestamp).not_to be_nil
        expect(request_span.start_timestamp).not_to eq(request_span.timestamp)
        expect(request_span.description).to eq("SET key")
        expect(request_span.data).to eq({ server: "127.0.0.1:6379/0" })
      end
    end

    context "calling multiple Redis commands in a MULTI transaction" do
      let(:result) do
        redis.multi do |multi|
          multi.set("key", "value")
          multi.incr("counter")
        end
      end

      it "records the Redis call's span with command and key" do
        transaction = Sentry.start_transaction
        Sentry.get_current_scope.set_span(transaction)

        expect(result).to contain_exactly("OK", kind_of(Numeric))
        request_span = transaction.span_recorder.spans.last
        expect(request_span.description).to eq("MULTI, SET key, INCR counter, EXEC")
      end
    end
  end

  context "with tracing disabled" do
    before do
      perform_basic_setup do |config|
        config.traces_sample_rate = 0.0
      end
    end

    context "calling Redis SET command" do
      let(:result) { redis.set("key", "value") }

      it "works as usual" do
        expect(result).to eq("OK")
      end
    end
  end
end