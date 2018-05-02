require 'spec_helper'

describe Toccatore::UsageUpdate, vcr: true do
  # let(:query_options) { { from_date: "2015-04-07", until_date: "2015-04-08", rows: 1000, offset: 0 } }

  # before(:each) { allow(Time).to receive(:now).and_return(Time.mktime(2015, 4, 8)) }

  context "get_total" do
    it "with works" do
      expect(subject.get_total()).to eq(650)
    end

    it "with no works" do
      expect(subject.get_total()).to eq(0)
    end
  end

  context "queue_url" do
    it "should return the correct queue url" do
      response = subject.queue_url
      expect(response).to eq("https://sqs.#{ENV['AWS_REGION']}.amazonaws.com/404017989009/stage_usage")
    end
  end

end
