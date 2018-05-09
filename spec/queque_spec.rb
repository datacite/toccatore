# require 'spec_helper'

# describe Toccatore::UsageUpdate, vcr: true do

#   # let(:queue_url){"https://sqs.#{ENV['AWS_REGION']}.amazonaws.com/404017989009/test_usage"}
#   # let(:queue_name){:test_usage}

#   # before do
#   #   # subject.new({:stub_responses => true})
#   #   body = File.read(fixture_path + 'usage_event.json')
#   #   result = OpenStruct.new(body: JSON.parse(body) )
#   #   subject.loopy.stub_responses(:create_queue, queue_url: queue_url)
#   #   subject.loopy.send_message({queue_url: queue_url, message_body:result.to_json})
#   # end
  
#   context "get_total" do
#     it "when there are messages" do
#       puts subject.queue_url
#       expect(subject.get_total()).to eq(1)
#     end

#     it "when the queue is empty" do
#       expect(subject.get_total()).to eq(0)
#     end
#   end

#   context "queue_url" do
#     it "should return always correct queue url" do
#       puts subject.queue_url
#       response = subject.queue_url
#       expect(response).to eq("https://sqs.#{ENV['AWS_REGION']}.amazonaws.com/404017989009/test_usage")
#     end

#     it "should fail if the queue doesn exist" do

#     end
#   end

#   context "get_message" do
#     it "should return one message when there are multiple messages" do
#       expect(subject.get_message.size).to eq(1)
#     end

#     it "should return no meessage when the queue is empty" do
#       expect(subject.get_message.size).to eq(0)
#     end
#   end

#   context "delete_message" do
#     it "should delete a message that exist" do
#       msg = subject.get_message
#       response = subject.delete_message msg
#       expect(response.successful?).to eq(true)
#     end

#     it "should return an error if a message doesnot exist" do

#     end
#   end

# end
