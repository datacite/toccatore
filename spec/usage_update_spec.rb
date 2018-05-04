# require 'spec_helper'

# describe Toccatore::UsageUpdate, vcr: true do
#   # let(:queue_url){"https://sqs.#{ENV['AWS_REGION']}.amazonaws.com/404017989009/test_usage"}
#   let(:lented){Toccatore::UsageUpdate}

#   # before(:context) do
#   #   @client_aws_sqs = Aws::SQS::Client.new
#   #   body = { report_id: "https://metrics.test.datacite.org/reports/2018-3-DataONE" }.to_json
#   #   options = {
#   #     queue_url: "https://sqs.#{ENV['AWS_REGION']}.amazonaws.com/404017989009/test_usage", 
#   #     message_body: body,
#   #     message_attributes: {
#   #       "report-id" => {
#   #         string_value: "https://metrics.test.datacite.org/reports/2018-3-DataONE",
#   #         data_type: "String"
#   #       }
#   #     }
#   #   }

#   # end

#   context "queue_jobs" do
#     it "should report if there are no works returned by the Usage Queue" do
#       response = subject.queue_jobs
#       expect(response).to eq(0)
#     end
  
#     it "should report if there are works returned by the Usage Queue" do
#       response = subject.queue_jobs
#       expect(response).to eq(3)
#     end
#   end

#   # context "format_event" do
#   #   it "should report if there are no works returned by the Usage Queue" do
#   #     body = File.read(fixture_path + 'usage_update_nil.json')
#   #     result = OpenStruct.new(body: JSON.parse(body) )
#   #     expect(subject.format_event(result)).to eq([])
#   #   end
  
#   #   it "should report if there are works returned by the Usage Queue" do
#   #     body = File.read(fixture_path + 'usage_update.json')
#   #     result = OpenStruct.new(body: JSON.parse(body) )
#   #     expect(subject.format_event(result).length).to eq(40)
#   #   end
#   # end


#   context "get_data" do
#     it "should report if there are no works returned by the Usage Queue" do
#       response = subject.get_data(subject.get_message)
#       expect(response.body["data"]["report"]["report-header"]["report-name"]).to eq("Dataset Master Report")
#     end

#     # it "should report if there are works returned by the Queue" do
#     #   # response = subject.get_data()
#     #   # expect(response.body["report"]["response"]["numFound"]).to eq(650)
#     #   # doc = response.body["report"]["response"]["docs"].first
#     #   # expect(doc["doi"]).to eq("10.7480/KNOB.113.2014.3")
#     # end

#     # it "Should return one message" do
#     #   body = File.read(fixture_path + 'usage_event.json')
#     #   @client_aws_sqs.stub_responses(:receive_message, messages: [body: JSON.parse(body)])
#     #   response = @client_aws_sqs.receive_message({queue_url: queue_url})
#     #   expect ( response.successful? ).should be_truthy
#     #   expect ( response.messages.length ).should eq(1)
#     #   expect ( response.messages.first.class).should eq(Aws::SQS::Types::Message)
#     #   expect ( response.messages.first.body).should eq(JSON.parse(body))
#     # end

#     # it "Should return two messages" do
#     #   body = File.read(fixture_path + 'usage_event.json')
#     #   @client_aws_sqs.stub_responses(:receive_message, messages: [{body: JSON.parse(body)}, {body: JSON.parse(body)}])
#     #   response = @client_aws_sqs.receive_message({queue_url: queue_url, max_number_of_messages: 10})
#     #   expect ( response.successful? ).should be_truthy
#     #   expect ( response.messages.length ).should eq(2)
#     #   expect ( response.messages.first.body).should eq(JSON.parse(body))
#     #   expect ( response.messages.last.body).should eq(JSON.parse(body))
#     # end

#     # it "Should return no messages" do
#     #   @client_aws_sqs.stub_responses(:receive_message, messages: [])
#     #   response = @client_aws_sqs.receive_message({queue_url: queue_url})
#     #   expect ( response.successful? ).should be_truthy
#     #   expect ( response.messages.length ).should eq(0)
#     # end
#   end

#   context "parse_data" do
#     it "should report if there are no works returned by the Queue" do
#       body = File.read(fixture_path + 'usage_update_nil.json')
#       result = OpenStruct.new(body:  JSON.parse(body) )
#       expect(subject.parse_data(result)).to eq([{"status"=>"404", "title"=>"The resource you are looking for doesn't exist."}])
#     end

#     it "should report if there are works returned by the Queue" do
#       body = File.read(fixture_path + 'usage_update.json')
#       result = OpenStruct.new(body: JSON.parse(body) )
#       response = subject.parse_data(result, source_token: ENV['SOURCE_TOKEN'])
#       expect(response.length).to eq(2)
#       expect(response.last.except("id")).to eq("subj"=>{"pid"=>"https://metrics.test.datacite.org/reports/2018-3-Dash", "issued"=>"2128-04-09"},"total"=>3,"message-action" => "add", "subj-id"=>"https://metrics.test.datacite.org/reports/2018-3-Dash", "obj-id"=>"https://doi.org/10.7291/d1q94r", "relation-type-id"=>"unique-dataset-investigations-regular", "source-id"=>"datacite", "occurred-at"=>"2128-04-09", "license" => "https://creativecommons.org/publicdomain/zero/1.0/", "source-token" => "28276d12-b320-41ba-9272-bb0adc3466ff")
#     end

#     # it "should report if there are works ignored because of an IsIdenticalTo relation" do
#     #   body = File.read(fixture_path + 'datacite_related_is_identical.json')
#     #   result = OpenStruct.new(body: { "data" => JSON.parse(body) })
#     #   expect(subject.parse_data(result)).to eq([])
#     # end

#     it "should catch timeout errors with the Queue" do
#       result = OpenStruct.new(body: { "errors" => [{ "title" => "the server responded with status 408 for https://search.datacite.org", "status" => 408 }] })
#       response = subject.parse_data(result)
#       expect(response).to eq(result.body["errors"])
#     end
#   end

#   context "push_data" do
#     it "should report if there are no works returned by the Queue" do
#       result = []
#       expect { subject.push_data(result) }.to output("No works found in the Queue.\n").to_stdout
#     end

#     # it "should report if there are works returned by the Queue" do
#     #   body = File.read(fixture_path + 'usage_update.json')
#     #   result = OpenStruct.new(body:  JSON.parse(body) )
#     #   result = subject.parse_data(result, source_token: ENV['SOURCE_TOKEN'])
#     #   options = { push_url: ENV['EVENTDATA_URL'], access_token: ENV['EVENTDATA_TOKEN'] }
#     #   expect { subject.push_data(result, options) }.to output(/https:\/\/doi.org\/10.15468\/dl.mb4das references https:\/\/doi.org\/10.3897\/phytokeys.12.2849 pushed to Event Data service.\n/).to_stdout
#     # end

#     it "should work with DataCite Event Data" do
#       body = File.read(fixture_path + 'usage_update.json')
#       result = OpenStruct.new(body: JSON.parse(body) )
#       result = subject.parse_data(result, source_token: ENV['SOURCE_TOKEN'])
#       options = { push_url: ENV['LAGOTTO_URL'], access_token: ENV['LAGOTTO_TOKEN'], jsonapi: true }
#       expect { subject.push_data(result, options) }.to output("https://metrics.test.datacite.org/reports/2018-3-Dash total-dataset-investigations-regular https://doi.org/10.7291/d1q94r pushed to Event Data service\nhttps://metrics.test.datacite.org/reports/2018-3-Dash unique-dataset-investigations-regular https://doi.org/10.7291/d1q94r pushed to Event Data service").to_stdout
#     end
#   end

# end
