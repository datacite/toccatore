require 'spec_helper'

describe Toccatore::Base, vcr: true do
  context "validate_doi" do
    it "datacite" do
      expect(subject.validate_doi("10.5061/DRYAD.8515")).to eq("10.5061/DRYAD.8515")
    end

    it "only prefix" do
      expect(subject.validate_doi("10.7554")).to be_nil
    end

    it "prefix with characters" do
      expect(subject.validate_doi("10.7554a/elife.01567")).to be_nil
    end
  end

  context "validate_prefix" do
    it "datacite" do
      expect(subject.validate_prefix("10.5061/DRYAD.8515")).to eq("10.5061")
    end

    it "only prefix" do
      expect(subject.validate_prefix("10.7554")).to be_nil
    end

    it "prefix with characters" do
      expect(subject.validate_prefix("10.7554a/elife.01567")).to be_nil
    end
  end

  context "get_doi_ra" do
    it "datacite" do
      expect(subject.get_doi_ra("10.5061")).to eq("DataCite")
    end

    it "crossref" do
      expect(subject.get_doi_ra("10.7554")).to eq("Crossref")
    end
  end

  context "unfreeze" do
    let(:query_options) { { from_date: "2015-04-07", until_date: "2015-04-08", rows: 1000, offset: 0 } }

    it "should unfreeze" do
      expect(subject.unfreeze(query_options)).to eq(:from_date=>"2015-04-07", :until_date=>"2015-04-08", :rows=>1000, :offset=>0)
    end
  end
end
