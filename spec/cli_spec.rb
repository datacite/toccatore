require 'spec_helper'
require 'toccatore/cli'

describe Toccatore::CLI do
  let(:subject) do
    described_class.new
  end

  describe "version" do
    it 'has version' do
      expect { subject.__print_version }.to output("0.3.1\n").to_stdout
    end
  end

  describe "orcid_update", vcr: true, :order => :defined do
    let(:push_url) { ENV['VOLPINO_URL'] }
    let(:access_token) { ENV['VOLPINO_TOKEN'] }
    let(:from_date) { "2015-04-07" }
    let(:until_date) { "2015-04-08" }
    let(:cli_options) { { push_url: push_url,
                          access_token: access_token,
                          from_date: from_date,
                          until_date: until_date } }

    it 'should succeed' do
      subject.options = cli_options
      expect { subject.orcid_update }.to output(/DOI 10.6084\/M9.FIGSHARE.1041547 for ORCID ID 0000-0002-3546-1048 pushed to Profiles service.\n/).to_stdout
    end

    it 'should query by DOI' do
      subject.options = cli_options.merge(doi: "10.5438/6423", from_date: "2013-01-01", until_date: "2017-12-31")
      expect { subject.orcid_update }.to output(/DOI 10.5438\/6423 for ORCID ID 0000-0001-5331-6592 pushed to Profiles service.\n/).to_stdout
    end

    # it 'should delete' do
    #   subject.options = cli_options.merge(doi: "10.6084/M9.FIGSHARE.4126869.V1", from_date: "2013-01-01", until_date: "2017-12-31", claim_action: "delete")
    #   expect { subject.orcid_update }.to output(/Delete DOI 10.6084\/M9.FIGSHARE.4126869.V1 for ORCID ID 0000-0003-1013-1533 pushed to Profiles service.\n/).to_stdout
    # end

    it 'should query by ORCID ID' do
      subject.options = cli_options.merge(orcid: "0000-0002-3546-1048", from_date: "2013-01-01", until_date: "2017-12-31")
      expect { subject.orcid_update }.to output(/DOI 10.6084\/M9.FIGSHARE.1041547 for ORCID ID 0000-0002-3546-1048 pushed to Profiles service.\n/).to_stdout
    end

    it 'should succeed with no works' do
      from_date = "2009-04-07"
      until_date = "2009-04-08"
      subject.options = { push_url: push_url,
                          access_token: access_token,
                          from_date: from_date,
                          until_date: until_date }
      expect { subject.orcid_update }.to output("No works found for date range 2009-04-07 - 2009-04-08.\n").to_stdout
    end

    it 'should fail' do
      subject.options = cli_options.except(:access_token)
      expect { subject.orcid_update }.to output(/An error occured: Access token missing.\n/).to_stdout
    end
  end

  describe "datacite_related", vcr: true, :order => :defined do
    let(:push_url) { ENV['EVENTDATA_URL'] }
    let(:access_token) { ENV['EVENTDATA_TOKEN'] }
    let(:from_date) { "2015-04-07" }
    let(:until_date) { "2015-04-08" }
    let(:cli_options) { { push_url: push_url,
                          access_token: access_token,
                          from_date: from_date,
                          until_date: until_date } }

    it 'should succeed' do
      subject.options = cli_options
      expect { subject.datacite_related }.to output(/https:\/\/doi.org\/10.5281\/zenodo.16396 is_supplement_to https:\/\/doi.org\/10.1007\/s11548-015-1180-7 pushed to Event Data service.\n/).to_stdout
    end

    it 'should query by DOI' do
      subject.options = cli_options.merge(doi: "10.5438/CT8B-X1CE", from_date: "2013-01-01", until_date: "2017-12-31")
      expect { subject.datacite_related }.to output(/https:\/\/doi.org\/10.5438\/ct8b-x1ce references https:\/\/doi.org\/10.1016\/j.aeolia.2015.08.001 pushed to Event Data service.\n/).to_stdout
    end

    it 'should query by related_identifier' do
      subject.options = cli_options.merge(related_identifier: "10.7554/elife.01567", from_date: "2013-01-01", until_date: "2017-12-31")
      expect { subject.datacite_related }.to output(/https:\/\/doi.org\/10.5061\/dryad.b835k is_referenced_by https:\/\/doi.org\/10.7554\/elife.01567 pushed to Event Data service.\n/).to_stdout
    end

    it 'should succeed with no works' do
      from_date = "1899-04-07"
      until_date = "1899-04-08"
      subject.options = { push_url: push_url,
                          access_token: access_token,
                          from_date: from_date,
                          until_date: until_date }
      expect { subject.datacite_related }.to output("No works found for date range 1899-04-07 - 1899-04-08.\n").to_stdout
    end

    it 'should fail' do
      subject.options = cli_options.except(:access_token)
      expect { subject.datacite_related }.to output(/An error occured: Access token missing.\n/).to_stdout
    end
  end
end
