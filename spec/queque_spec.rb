require 'spec_helper'

describe Toccatore::UsageUpdate, vcr: true do

  
  context "get_total" do
    it "when is working with AWS" do
      expect(subject.get_total()).to respond_to(:+)
      expect(subject.get_total()).not_to respond_to(:each)
    end
  end

  context "queue_url" do
    it "should return always correct queue url" do
      response = subject.queue_url
      expect(response).to eq("https://sqs.#{ENV['AWS_REGION']}.amazonaws.com/404017989009/#{ENV['ENVIRONMENT']}_usage")
    end

    it "should fail if the queue doesn exist" do
      response = subject.queue_url({ queue_name: "stage_usage" })
      expect(response).to eq("https://sqs.#{ENV['AWS_REGION']}.amazonaws.com/404017989009/#{ENV['ENVIRONMENT']}_usage")
    end
  end

  context "get_message" do
    it "should return one message when there are multiple messages" do
      expect(subject.get_message).to respond_to(:messages)
    end

    it "should return no meessage when the queue is empty" do
      expect(subject.get_message).not_to respond_to(:+)
    end
  end

  # context "delete_message" do
  #   it "should delete a message that exist" do
  #     msg = subject.get_message
  #     response = subject.delete_message msg
  #     expect(response.successful?).to eq(true)
  #   end

  #   it "should return an error if a message doesnot exist" do

  #   end
  # end

end
