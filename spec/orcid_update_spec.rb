require 'spec_helper'

describe Toccatore::OrcidUpdate, vcr: true do
  let(:query_options) { { from_date: "2015-04-07", until_date: "2015-04-08", rows: 1000, offset: 0 } }

  before(:each) { allow(Time).to receive(:now).and_return(Time.mktime(2015, 4, 8)) }

  context "get_query_url" do
    it "default" do
      expect(subject.get_query_url(query_options)).to eq("https://search.datacite.org/api?q=nameIdentifier%3AORCID%5C%3A*&start=0&rows=1000&fl=doi%2Ccreator%2Ctitle%2Cpublisher%2CpublicationYear%2CresourceTypeGeneral%2Cdatacentre_symbol%2CrelatedIdentifier%2CnameIdentifier%2Cxml%2Cminted%2Cupdated&fq=updated%3A%5B2015-04-07T00%3A00%3A00Z+TO+2015-04-08T23%3A59%3A59Z%5D+AND+has_metadata%3Atrue+AND+is_active%3Atrue&wt=json")
    end

    it "with zero rows" do
      expect(subject.get_query_url(query_options.merge(rows: 0))).to eq("https://search.datacite.org/api?q=nameIdentifier%3AORCID%5C%3A*&start=0&rows=0&fl=doi%2Ccreator%2Ctitle%2Cpublisher%2CpublicationYear%2CresourceTypeGeneral%2Cdatacentre_symbol%2CrelatedIdentifier%2CnameIdentifier%2Cxml%2Cminted%2Cupdated&fq=updated%3A%5B2015-04-07T00%3A00%3A00Z+TO+2015-04-08T23%3A59%3A59Z%5D+AND+has_metadata%3Atrue+AND+is_active%3Atrue&wt=json")
    end

    it "with different from_date and until_date" do
      expect(subject.get_query_url(query_options.merge(from_date: "2015-04-05", until_date: "2015-04-05"))).to eq("https://search.datacite.org/api?q=nameIdentifier%3AORCID%5C%3A*&start=0&rows=1000&fl=doi%2Ccreator%2Ctitle%2Cpublisher%2CpublicationYear%2CresourceTypeGeneral%2Cdatacentre_symbol%2CrelatedIdentifier%2CnameIdentifier%2Cxml%2Cminted%2Cupdated&fq=updated%3A%5B2015-04-05T00%3A00%3A00Z+TO+2015-04-05T23%3A59%3A59Z%5D+AND+has_metadata%3Atrue+AND+is_active%3Atrue&wt=json")
    end

    it "with offset" do
      expect(subject.get_query_url(query_options.merge(offset: 250))).to eq("https://search.datacite.org/api?q=nameIdentifier%3AORCID%5C%3A*&start=250&rows=1000&fl=doi%2Ccreator%2Ctitle%2Cpublisher%2CpublicationYear%2CresourceTypeGeneral%2Cdatacentre_symbol%2CrelatedIdentifier%2CnameIdentifier%2Cxml%2Cminted%2Cupdated&fq=updated%3A%5B2015-04-07T00%3A00%3A00Z+TO+2015-04-08T23%3A59%3A59Z%5D+AND+has_metadata%3Atrue+AND+is_active%3Atrue&wt=json")
    end

    it "with rows" do
      expect(subject.get_query_url(query_options.merge(rows: 250))).to eq("https://search.datacite.org/api?q=nameIdentifier%3AORCID%5C%3A*&start=0&rows=250&fl=doi%2Ccreator%2Ctitle%2Cpublisher%2CpublicationYear%2CresourceTypeGeneral%2Cdatacentre_symbol%2CrelatedIdentifier%2CnameIdentifier%2Cxml%2Cminted%2Cupdated&fq=updated%3A%5B2015-04-07T00%3A00%3A00Z+TO+2015-04-08T23%3A59%3A59Z%5D+AND+has_metadata%3Atrue+AND+is_active%3Atrue&wt=json")
    end
  end

  context "get_total" do
    it "with works" do
      expect(subject.get_total(query_options)).to eq(55)
    end

    it "with no works" do
      expect(subject.get_total(query_options.merge(from_date: "2009-04-07", until_date: "2009-04-08"))).to eq(0)
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
      response = subject.get_data(query_options.merge(from_date: "2009-04-07", until_date: "2009-04-08"))
      expect(response.body["data"]["response"]["numFound"]).to eq(0)
    end

    it "should report if there are works returned by the Datacite Metadata Search API" do
      response = subject.get_data(query_options)
      expect(response.body["data"]["response"]["numFound"]).to eq(55)
      doc = response.body["data"]["response"]["docs"].first
      expect(doc["doi"]).to eq("10.6084/M9.FIGSHARE.1041547")
    end

    it "should allow queries by ORCID ID of the Datacite Metadata Search API" do
      response = subject.get_data({ orcid: "0000-0002-3546-1048", from_date: "2013-01-01", until_date: "2016-12-31", rows: 1000, offset: 0 })
      expect(response.body["data"]["response"]["numFound"]).to eq(68)
      doc = response.body["data"]["response"]["docs"].first
      expect(doc["doi"]).to eq("10.6084/M9.FIGSHARE.1371005.V1")
    end

    it "should allow queries by DOI of the Datacite Metadata Search API" do
      response = subject.get_data({ doi: "10.5438/6423", from_date: "2013-01-01", until_date: "2016-12-31", rows: 1000, offset: 0 })
      expect(response.body["data"]["response"]["numFound"]).to eq(1)
      doc = response.body["data"]["response"]["docs"].first
      name_identifiers = doc["nameIdentifier"]
      expect(name_identifiers.count).to eq(22)
      expect(name_identifiers.first).to eq("ORCID:0000-0001-5331-6592")
    end

    it "should catch errors with the Datacite Metadata Search API" do
      stub = stub_request(:get, subject.get_query_url(query_options.merge(rows: 0, source_id: subject.source_id))).to_return(:status => [408])
      response = subject.get_data(query_options.merge(rows: 0, source_id: subject.source_id))
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

    it "should report if there are works ignored because of an IsIdenticalTo relation" do
      body = File.read(fixture_path + 'orcid_update_is_identical.json')
      result = OpenStruct.new(body: { "data" => JSON.parse(body) })
      expect(subject.parse_data(result)).to eq([])
    end

    it "should report if there are works ignored because of an IsPartOf relation" do
      body = File.read(fixture_path + 'orcid_update_is_part.json')
      result = OpenStruct.new(body: { "data" => JSON.parse(body) })
      expect(subject.parse_data(result)).to eq([])
    end

        it "should report if there are works ignored because of an IsPreviousVersionOf relation" do
      body = File.read(fixture_path + 'orcid_update_is_previous.json')
      result = OpenStruct.new(body: { "data" => JSON.parse(body) })
      expect(subject.parse_data(result)).to eq([])
    end

    it "should report if there are works because of an IsIdenticalTo relation and delete action" do
      body = File.read(fixture_path + 'orcid_update_is_identical.json')
      result = OpenStruct.new(body: { "data" => JSON.parse(body) })
      expect(subject.parse_data(result, claim_action: "delete")).to eq([{"orcid"=>"0000-0003-1013-1533", "doi"=>"10.6084/M9.FIGSHARE.4126869.V1", "source_id"=>"orcid_update", "claim_action"=>"delete"}])
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
      expect { subject.push_data(result, query_options) }.to output("No works found for date range 2015-04-07 - 2015-04-08.\n").to_stdout
    end

    it "should report if there are works returned by the Datacite Metadata Search API" do
      body = File.read(fixture_path + 'orcid_update.json')
      result = OpenStruct.new(body: { "data" => JSON.parse(body) })
      result = subject.parse_data(result)
      options = { push_url: ENV['VOLPINO_URL'], access_token: ENV['VOLPINO_TOKEN'] }
      expect { subject.push_data(result, options) }.to output(/Create DOI 10.6084\/M9.FIGSHARE.1041547 for ORCID ID 0000-0002-3546-1048 pushed to Profiles service.\n/).to_stdout
    end

    it "should delete claims" do
      body = File.read(fixture_path + 'orcid_update_is_identical.json')
      result = OpenStruct.new(body: { "data" => JSON.parse(body) })
      result = subject.parse_data(result, claim_action: "delete")
      options = { push_url: ENV['VOLPINO_URL'], access_token: ENV['VOLPINO_TOKEN'], from_date: "2013-01-01", until_date: "2016-12-31", claim_action: "delete" }
      expect { subject.push_data(result, options) }.to output(/Delete DOI 10.6084\/M9.FIGSHARE.4126869.V1 for ORCID ID 0000-0003-1013-1533 pushed to Profiles service.\n/).to_stdout
    end
  end

  context "unfreeze" do
    it "should unfreeze" do
      expect(subject.unfreeze(query_options)).to eq(:from_date=>"2015-04-07", :until_date=>"2015-04-08", :rows=>1000, :offset=>0)
    end
  end
end
