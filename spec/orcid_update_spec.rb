require 'spec_helper'

describe Toccatore::OrcidUpdate, vcr: true do
  before(:each) { allow(Time).to receive(:now).and_return(Time.mktime(2015, 4, 8)) }

  context "get_query_url" do
    it "default" do
      expect(subject.get_query_url).to eq("https://search.datacite.org/api?q=nameIdentifier%3AORCID%5C%3A*&start=0&rows=1000&fl=doi%2Ccreator%2Ctitle%2Cpublisher%2CpublicationYear%2CresourceTypeGeneral%2Cdatacentre_symbol%2CrelatedIdentifier%2CnameIdentifier%2Cxml%2Cminted%2Cupdated&fq=updated%3A%5B2015-04-07T00%3A00%3A00Z+TO+2015-04-08T23%3A59%3A59Z%5D+AND+has_metadata%3Atrue+AND+is_active%3Atrue&wt=json")
    end

    it "with zero rows" do
      expect(subject.get_query_url(rows: 0)).to eq("https://search.datacite.org/api?q=nameIdentifier%3AORCID%5C%3A*&start=0&rows=0&fl=doi%2Ccreator%2Ctitle%2Cpublisher%2CpublicationYear%2CresourceTypeGeneral%2Cdatacentre_symbol%2CrelatedIdentifier%2CnameIdentifier%2Cxml%2Cminted%2Cupdated&fq=updated%3A%5B2015-04-07T00%3A00%3A00Z+TO+2015-04-08T23%3A59%3A59Z%5D+AND+has_metadata%3Atrue+AND+is_active%3Atrue&wt=json")
    end

    it "with different from_date and until_date" do
      expect(subject.get_query_url(from_date: "2015-04-05", until_date: "2015-04-05")).to eq("https://search.datacite.org/api?q=nameIdentifier%3AORCID%5C%3A*&start=0&rows=1000&fl=doi%2Ccreator%2Ctitle%2Cpublisher%2CpublicationYear%2CresourceTypeGeneral%2Cdatacentre_symbol%2CrelatedIdentifier%2CnameIdentifier%2Cxml%2Cminted%2Cupdated&fq=updated%3A%5B2015-04-05T00%3A00%3A00Z+TO+2015-04-05T23%3A59%3A59Z%5D+AND+has_metadata%3Atrue+AND+is_active%3Atrue&wt=json")
    end

    it "with offset" do
      expect(subject.get_query_url(offset: 250)).to eq("https://search.datacite.org/api?q=nameIdentifier%3AORCID%5C%3A*&start=250&rows=1000&fl=doi%2Ccreator%2Ctitle%2Cpublisher%2CpublicationYear%2CresourceTypeGeneral%2Cdatacentre_symbol%2CrelatedIdentifier%2CnameIdentifier%2Cxml%2Cminted%2Cupdated&fq=updated%3A%5B2015-04-07T00%3A00%3A00Z+TO+2015-04-08T23%3A59%3A59Z%5D+AND+has_metadata%3Atrue+AND+is_active%3Atrue&wt=json")
    end

    it "with rows" do
      expect(subject.get_query_url(rows: 250)).to eq("https://search.datacite.org/api?q=nameIdentifier%3AORCID%5C%3A*&start=0&rows=250&fl=doi%2Ccreator%2Ctitle%2Cpublisher%2CpublicationYear%2CresourceTypeGeneral%2Cdatacentre_symbol%2CrelatedIdentifier%2CnameIdentifier%2Cxml%2Cminted%2Cupdated&fq=updated%3A%5B2015-04-07T00%3A00%3A00Z+TO+2015-04-08T23%3A59%3A59Z%5D+AND+has_metadata%3Atrue+AND+is_active%3Atrue&wt=json")
    end
  end

  context "get_total" do
    it "with works" do
      expect(subject.get_total).to eq(55)
    end

    it "with no works" do
      expect(subject.get_total(from_date: "2009-04-07", until_date: "2009-04-08")).to eq(0)
    end
  end

  context "queue_jobs" do
    it "should report if there are no works returned by the Datacite Metadata Search API" do
      response = subject.queue_jobs(from_date: "2009-04-07", until_date: "2009-04-08")
      expect(response).to eq(0)
    end

    it "should report if there are works returned by the Datacite Metadata Search API" do
      response = subject.queue_jobs
      expect(response).to eq(55)
    end
  end

  context "get_data" do
    it "should report if there are no works returned by the Datacite Metadata Search API" do
      response = subject.get_data(from_date: "2009-04-07", until_date: "2009-04-08")
      expect(response.body["data"]["response"]["numFound"]).to eq(0)
    end

    it "should report if there are works returned by the Datacite Metadata Search API" do
      response = subject.get_data
      expect(response.body["data"]["response"]["numFound"]).to eq(55)
      doc = response.body["data"]["response"]["docs"].first
      expect(doc["doi"]).to eq("10.6084/M9.FIGSHARE.1041547")
    end

    it "should catch errors with the Datacite Metadata Search API" do
      stub = stub_request(:get, subject.get_query_url(rows: 0, source_id: subject.source_id)).to_return(:status => [408])
      response = subject.get_data(rows: 0, source_id: subject.source_id)
      expect(response.body).to eq("errors"=>[{"status"=>408, "title"=>"Request timeout"}])
      expect(stub).to have_been_requested
    end
  end

  context "parse_data" do
    it "should report if there are no works returned by the Datacite Metadata Search API" do
      body = File.read(fixture_path + 'orcid_update_nil.json')
      result = OpenStruct.new(body: { "data" => JSON.parse(body) })
      expect(subject.parse_data(result)).to eq([])
    end

    it "should report if there are works returned by the Datacite Metadata Search API" do
      body = File.read(fixture_path + 'orcid_update.json')
      result = OpenStruct.new(body: { "data" => JSON.parse(body) })
      response = subject.parse_data(result)

      expect(response.length).to eq(56)
      expect(response.first).to eq("orcid"=>"0000-0001-8478-7549",
                                   "doi"=>"10.6084/M9.FIGSHARE.1226424",
                                   "source_id"=>"orcid_update",
                                   "claim_action" => "create")
    end

    it "should catch timeout errors with the Datacite Metadata Search API" do
      result = OpenStruct.new(body: { "errors" => [{ "title" => "the server responded with status 408 for https://search.datacite.org", "status" => 408 }] })
      response = subject.parse_data(result)
      expect(response).to eq(result.body["errors"])
    end
  end

  context "push_data" do
    it "should report if there are no works returned by the Datacite Metadata Search API" do
      result = []
      response = subject.push_data(result)
      expect(response.count).to eq(0)
    end

    it "should report if there are works returned by the Datacite Metadata Search API" do
      body = File.read(fixture_path + 'orcid_update.json')
      result = OpenStruct.new(body: { "data" => JSON.parse(body) })
      result = subject.parse_data(result)
      options = { push_url: ENV['VOLPINO_URL'], access_token: ENV['VOLPINO_TOKEN'] }

      response = subject.push_data(result, options)
      expect(response.count).to eq(56)
      claim = response.first
      expect(claim.body["data"]["attributes"]).to eq("orcid"=>"0000-0001-8478-7549",
                                                     "doi"=>"10.6084/M9.FIGSHARE.1226424",
                                                     "source-id"=>"orcid_update",
                                                     "state"=>"waiting",
                                                     "claim-action"=>nil,
                                                     "claimed-at"=>nil)
    end
  end
end
