require 'spec_helper'

describe Toccatore::UsageUpdate, vcr: true do

  let(:queue_url){"https://sqs.#{ENV['AWS_REGION']}.amazonaws.com/404017989009/test_usage"}
  let(:queue_name){:test_usage}
  let!(:sqs)     {Aws::SQS::Client.new(region: ENV['AWS_REGION'].to_s, stub_responses: true)}
  let!(:body)    {File.read(fixture_path + 'usage_event.json')}
  let!(:message){[body: body]}

  let(:dummy_message){sqs.receive_message(queue_url: queue_url, max_number_of_messages: 1, wait_time_seconds: 1)}


  describe "get_data" do
    context "when there are messages" do
      it "should return the data for one message" do
        sqs.stub_responses(:receive_message, messages: message)
        sqs.stub_responses(:receive_message, messages: message)
        sqs.stub_responses(:receive_message, messages: message)
        sqs.stub_responses(:receive_message, messages: message)
        response = sqs.receive_message({queue_url: queue_url})
        response = subject.get_data(response)
        expect(response.body["data"]["report"]["report-header"]["report-name"]).to eq("Dataset Master Report")
      end
    end

    context "when there is ONE message" do
      it "should return the data for one message" do
        sqs.stub_responses(:receive_message, messages: message)
        response = sqs.receive_message({queue_url: queue_url})
        response = subject.get_data(response)
        expect(response.body["data"]["report"]["report-header"]["report-name"]).to eq("Dataset Master Report")
      end
    end

    context "when there are NOT messages" do
      it "should return empty" do
        sqs.stub_responses(:receive_message, messages: [])
        response = sqs.receive_message({queue_url: queue_url})
        response = subject.get_data(response)
        expect(response.body["errors"]).to eq("Queue is empty")
      end
    end
  end

  describe "parse_data" do
    context "when the usage event was NOT found" do
      it "should return errors" do
        body = File.read(fixture_path + 'usage_update_nil.json')
        result = OpenStruct.new(body:  JSON.parse(body) )
        expect(subject.parse_data(result)).to eq([{"status"=>"404", "title"=>"The resource you are looking for doesn't exist."}])
      end
    end

    context "when the usage report was NOT found" do
      it "should return errors" do
        body = File.read(fixture_path + 'usage_update_nil.json')
        result = OpenStruct.new(body:  JSON.parse(body) )
        expect(subject.parse_data(result)).to eq([{"status"=>"404", "title"=>"The resource you are looking for doesn't exist."}])
      end
    end

    context "when the report was found" do
      it "should parsed it correctly" do
        body = File.read(fixture_path + 'usage_update.json')
        result = OpenStruct.new(body: JSON.parse(body) )
        response = subject.parse_data(result, source_token: ENV['SOURCE_TOKEN'])
        expect(response.length).to eq(2)
        expect(response.last.except("uuid")).to eq("subj"=>{"pid"=>"https://metrics.test.datacite.org/reports/2018-3-Dash", "issued"=>"2128-04-09"},"total"=>3,"message-action" => "add", "subj-id"=>"https://metrics.test.datacite.org/reports/2018-3-Dash", "obj-id"=>"https://doi.org/10.7291/d1q94r", "relation-type-id"=>"unique-dataset-investigations-regular", "source-id"=>"datacite-usage", "occurred-at"=>"2128-04-09", "license" => "https://creativecommons.org/publicdomain/zero/1.0/", "source-token" => "43ba99ae-5cf0-11e8-9c2d-fa7ae01bbebc")
      end

      it "should parsed it correctly when it has five metrics  and two DOIs" do
        body = File.read(fixture_path + 'usage_update_3.json')
        result = OpenStruct.new(body: JSON.parse(body) )
        response = subject.parse_data(result, source_token: ENV['SOURCE_TOKEN'])
        expect(response.length).to eq(5)
        expect(response.last.except("uuid")).to eq("message-action"=>"add", "subj-id"=>"https://metrics.test.datacite.org/reports/2018-3-Dash", "subj"=>{"pid"=>"https://metrics.test.datacite.org/reports/2018-3-Dash", "issued"=>"2128-04-09"}, "total"=>208, "obj-id"=>"https://doi.org/10.6071/z7wc73", "relation-type-id"=>"Unique-Dataset-Requests-Machine", "source-id"=>"datacite-usage", "source-token"=>"43ba99ae-5cf0-11e8-9c2d-fa7ae01bbebc", "occurred-at"=>"2128-04-09", "license"=>"https://creativecommons.org/publicdomain/zero/1.0/")
      end

      it "should parsed it correctly when it has two metrics per DOI " do
        body = File.read(fixture_path + 'usage_update_2.json')
        result = OpenStruct.new(body: JSON.parse(body) )
        response = subject.parse_data(result, source_token: ENV['SOURCE_TOKEN'])
        expect(response.length).to eq(4)
        expect(response.last.except("uuid")).to eq("message-action"=>"add", "subj-id"=>"https://metrics.test.datacite.org/reports/2018-3-Dash", "subj"=>{"pid"=>"https://metrics.test.datacite.org/reports/2018-3-Dash", "issued"=>"2128-04-09"}, "total"=>208, "obj-id"=>"https://doi.org/10.6071/z7wc73", "relation-type-id"=>"Unique-Dataset-Requests-Machine", "source-id"=>"datacite-usage", "source-token"=>"43ba99ae-5cf0-11e8-9c2d-fa7ae01bbebc", "occurred-at"=>"2128-04-09", "license"=>"https://creativecommons.org/publicdomain/zero/1.0/")
      end

      it "should send a warning if there are more than 4 metrics" do
        body = File.read(fixture_path + 'usage_update_1.json')
        result = OpenStruct.new(body: JSON.parse(body) )
        response = subject.parse_data(result, source_token: ENV['SOURCE_TOKEN'])
        expect(response.length).to eq(1)
        expect(response.last.body).to eq({"errors"=>"There are too many instances in 10.7291/D1Q94R for report https://metrics.test.datacite.org/reports/2018-3-Dash. There can only be 4"})
      end
    end
  end

  context "push_data" do
    let!(:events) {create_list(:event,10)}
    it "should report if there are no works returned by the Queue" do
      result = []
      expect { subject.push_data(result) }.to output("No works found in the Queue.\n").to_stdout
    end

    it "should fail if format of the event is wrong" do
      body = File.read(fixture_path + 'usage_events.json')
      expect = File.read(fixture_path + 'event_data_resp_2')
      result = JSON.parse(body)
      options = { push_url: ENV['LAGOTTINO_URL'], access_token: ENV['ACCESS_TOKEN'], jsonapi: true }
      expect(subject.push_data(result, options)).to eq(4)
    end

    it "should work with DataCite Event Data 2" do
      dd = events.map {|event| event.to_h.stringify_keys}
      all_events = dd.map {|item| item.map{ |k, v| [k.dasherize, v] }.to_h}
      options = { push_url: ENV['LAGOTTINO_URL'], access_token: ENV['ACCESS_TOKEN'], jsonapi: true }
      # expect(subject.push_data(all_events, options)).to eq(0)
    end
  end

end
