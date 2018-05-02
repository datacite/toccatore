require 'spec_helper'

describe Toccatore::UsageUpdate, vcr: true do
  # let(:query_options) { { from_date: "2015-04-07", until_date: "2015-04-08", rows: 1000, offset: 0 } }

  # before(:each) { allow(Time).to receive(:now).and_return(Time.mktime(2015, 4, 8)) }

  # context "get_query_url" do
  #   it "default" do
  #     expect(subject.get_query_url(query_options)).to eq("https://search.datacite.org/api?q=relatedIdentifier%3ADOI%5C%3A*&start=0&rows=1000&fl=doi%2CresourceTypeGeneral%2CrelatedIdentifier%2CnameIdentifier%2Cminted%2Cupdated&fq=updated%3A%5B2015-04-07T00%3A00%3A00Z+TO+2015-04-08T23%3A59%3A59Z%5D+AND+has_metadata%3Atrue+AND+is_active%3Atrue&wt=json")
  #   end

  #   it "with zero rows" do
  #     expect(subject.get_query_url(query_options.merge(rows: 0))).to eq("https://search.datacite.org/api?q=relatedIdentifier%3ADOI%5C%3A*&start=0&rows=0&fl=doi%2CresourceTypeGeneral%2CrelatedIdentifier%2CnameIdentifier%2Cminted%2Cupdated&fq=updated%3A%5B2015-04-07T00%3A00%3A00Z+TO+2015-04-08T23%3A59%3A59Z%5D+AND+has_metadata%3Atrue+AND+is_active%3Atrue&wt=json")
  #   end

  #   it "with different from_date and until_date" do
  #     expect(subject.get_query_url(query_options.merge(from_date: "2015-04-05", until_date: "2015-04-05"))).to eq("https://search.datacite.org/api?q=relatedIdentifier%3ADOI%5C%3A*&start=0&rows=1000&fl=doi%2CresourceTypeGeneral%2CrelatedIdentifier%2CnameIdentifier%2Cminted%2Cupdated&fq=updated%3A%5B2015-04-05T00%3A00%3A00Z+TO+2015-04-05T23%3A59%3A59Z%5D+AND+has_metadata%3Atrue+AND+is_active%3Atrue&wt=json")
  #   end

  #   it "with offset" do
  #     expect(subject.get_query_url(query_options.merge(offset: 250))).to eq("https://search.datacite.org/api?q=relatedIdentifier%3ADOI%5C%3A*&start=250&rows=1000&fl=doi%2CresourceTypeGeneral%2CrelatedIdentifier%2CnameIdentifier%2Cminted%2Cupdated&fq=updated%3A%5B2015-04-07T00%3A00%3A00Z+TO+2015-04-08T23%3A59%3A59Z%5D+AND+has_metadata%3Atrue+AND+is_active%3Atrue&wt=json")
  #   end

  #   it "with rows" do
  #     expect(subject.get_query_url(query_options.merge(rows: 250))).to eq("https://search.datacite.org/api?q=relatedIdentifier%3ADOI%5C%3A*&start=0&rows=250&fl=doi%2CresourceTypeGeneral%2CrelatedIdentifier%2CnameIdentifier%2Cminted%2Cupdated&fq=updated%3A%5B2015-04-07T00%3A00%3A00Z+TO+2015-04-08T23%3A59%3A59Z%5D+AND+has_metadata%3Atrue+AND+is_active%3Atrue&wt=json")
  #   end
  # end

  context "get_total" do
    it "with works" do
      expect(subject.get_total()).to eq(650)
    end

    it "with no works" do
      expect(subject.get_total()).to eq(0)
    end
  end

  context "queue_jobs" do
    it "should report if there are no works returned by the Usage Queue" do
      response = subject.queue_jobs
      expect(response).to eq(0)
    end
  
    it "should report if there are works returned by the Usage Queue" do
      response = subject.queue_jobs
      expect(response).to eq(55)
    end
  end

  # context "format_event" do
  #   it "should report if there are no works returned by the Usage Queue" do
  #     body = File.read(fixture_path + 'usage_update_nil.json')
  #     result = OpenStruct.new(body: JSON.parse(body) )
  #     expect(subject.format_event(result)).to eq([])
  #   end
  
  #   it "should report if there are works returned by the Usage Queue" do
  #     body = File.read(fixture_path + 'usage_update.json')
  #     result = OpenStruct.new(body: JSON.parse(body) )
  #     expect(subject.format_event(result).length).to eq(40)
  #   end
  # end


  context "get_data" do
    it "should report if there are no works returned by the Usage Queue" do
      response = subject.get_data()
      expect(response.body["report"]["report-header"]["report-name"]).to eq(0)
    end

    it "should report if there are works returned by the Queue" do
      response = subject.get_data()
      expect(response.body["report"]["response"]["numFound"]).to eq(650)
      doc = response.body["report"]["response"]["docs"].first
      expect(doc["doi"]).to eq("10.7480/KNOB.113.2014.3")
    end

    # it "should allow queries by related_identifier of the Queue" do
    #   response = subject.get_data()
    #   expect(response.body["data"]["response"]["numFound"]).to eq(1)
    #   doc = response.body["data"]["response"]["docs"].first
    #   expect(doc["doi"]).to eq("10.5061/DRYAD.B835K")
    #   related_identifiers = doc["relatedIdentifier"]
    #   expect(related_identifiers.count).to eq(6)
    #   expect(related_identifiers[4]).to eq("IsReferencedBy:DOI:10.7554/ELIFE.01567")
    # end

    # it "should allow queries by DOI of the Queue" do
    #   response = subject.get_data()
    #   expect(response.body["data"]["response"]["numFound"]).to eq(1)
    #   doc = response.body["data"]["response"]["docs"].first
    #   related_identifiers = doc["relatedIdentifier"]
    #   expect(related_identifiers.count).to eq(25)
    #   expect(related_identifiers.first).to eq("HasPart:DOI:10.5281/ZENODO.30799")
    # end

    # it "should catch errors with the Queue" do
    #   stub = stub_request(:get, subject.get_query_url(query_options.merge(rows: 0, source_id: subject.source_id))).to_return(:status => [408])
    #   response = subject.get_data(query_options.merge(rows: 0, source_id: subject.source_id))
    #   expect(response.body).to eq("errors"=>[{"status"=>408, "title"=>"Request timeout"}])
    #   expect(stub).to have_been_requested
    # end
  end

  context "parse_data" do
    it "should report if there are no works returned by the Queue" do
      body = File.read(fixture_path + 'usage_update_nil.json')
      result = OpenStruct.new(body:  JSON.parse(body) )
      expect(subject.parse_data(result)).to eq([{"status"=>"404", "title"=>"The resource you are looking for doesn't exist."}])
    end

    it "should report if there are works returned by the Queue" do
      body = File.read(fixture_path + 'usage_update.json')
      result = OpenStruct.new(body: JSON.parse(body) )
      response = subject.parse_data(result, source_token: ENV['SOURCE_TOKEN'])
      puts response.last
      expect(response.length).to eq(2)
      expect(response.last.except("id")).to eq("subj"=>{"pid"=>"https://metrics.test.datacite.org/reports/2018-3-Dash", "issued"=>"2128-04-09"},"total"=>3,"message-action" => "add", "subj-id"=>"https://metrics.test.datacite.org/reports/2018-3-Dash", "obj-id"=>"https://doi.org/10.7291/d1q94r", "relation-type-id"=>"unique-dataset-investigations-regular", "source-id"=>"datacite", "occurred-at"=>"2128-04-09", "license" => "https://creativecommons.org/publicdomain/zero/1.0/", "source-token" => "28276d12-b320-41ba-9272-bb0adc3466ff")
    end

    # it "should report if there are works ignored because of an IsIdenticalTo relation" do
    #   body = File.read(fixture_path + 'datacite_related_is_identical.json')
    #   result = OpenStruct.new(body: { "data" => JSON.parse(body) })
    #   expect(subject.parse_data(result)).to eq([])
    # end

    it "should catch timeout errors with the Queue" do
      result = OpenStruct.new(body: { "errors" => [{ "title" => "the server responded with status 408 for https://search.datacite.org", "status" => 408 }] })
      response = subject.parse_data(result)
      expect(response).to eq(result.body["errors"])
    end
  end

  context "push_data" do
    it "should report if there are no works returned by the Queue" do
      result = []
      expect { subject.push_data(result) }.to output("No works found in the Queue.\n").to_stdout
    end

    # it "should report if there are works returned by the Queue" do
    #   body = File.read(fixture_path + 'usage_update.json')
    #   result = OpenStruct.new(body:  JSON.parse(body) )
    #   result = subject.parse_data(result, source_token: ENV['SOURCE_TOKEN'])
    #   options = { push_url: ENV['EVENTDATA_URL'], access_token: ENV['EVENTDATA_TOKEN'] }
    #   expect { subject.push_data(result, options) }.to output(/https:\/\/doi.org\/10.15468\/dl.mb4das references https:\/\/doi.org\/10.3897\/phytokeys.12.2849 pushed to Event Data service.\n/).to_stdout
    # end

    it "should work with DataCite Event Data" do
      body = File.read(fixture_path + 'usage_update.json')
      result = OpenStruct.new(body: JSON.parse(body) )
      result = subject.parse_data(result, source_token: ENV['SOURCE_TOKEN'])
      options = { push_url: ENV['LAGOTTO_URL'], access_token: ENV['LAGOTTO_TOKEN'], jsonapi: true }
      expect { subject.push_data(result, options) }.to output("https://metrics.test.datacite.org/reports/2018-3-Dash total-dataset-investigations-regular https://doi.org/10.7291/d1q94r pushed to Event Data service\nhttps://metrics.test.datacite.org/reports/2018-3-Dash unique-dataset-investigations-regular https://doi.org/10.7291/d1q94r pushed to Event Data service").to_stdout
    end
  end

end
