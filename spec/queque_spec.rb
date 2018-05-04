require 'spec_helper'

describe Toccatore::UsageUpdate, vcr: true do

  # before do
  #   @client_aws_sqs = Aws::SQS::Client.new
  # end
  
  context "get_total" do
    it "with works" do
      expect(subject.get_total()).to eq(3)
    end

    it "with no works" do
      expect(subject.get_total()).to eq(0)
    end
  end

  context "queue_url" do
    it "should return the correct queue url" do
      response = subject.queue_url
      expect(response).to eq("https://sqs.#{ENV['AWS_REGION']}.amazonaws.com/404017989009/test_usage")
    end
  end

  context "delete_message" do
    it "should return the correct queue url" do
      msg = subject.get_message
      response = subject.delete_message msg
      expect(response.successful?).to eq(true)
    end
  end

end
