require 'spec_helper'
require 'toccatore/cli'

describe Toccatore::CLI do
  let(:subject) do
    described_class.new
  end

  let(:push_url) { ENV['VOLPINO_URL'] }
  let(:access_token) { ENV['VOLPINO_TOKEN'] }
  let(:from_date) { "2015-04-07" }
  let(:until_date) { "2015-04-08" }
  let(:cli_options) { { push_url: push_url,
                        access_token: access_token,
                        from_date: from_date,
                        until_date: until_date } }

  describe "orcid_update", vcr: true, :order => :defined do
    it 'should succeed' do
      subject.options = cli_options
      expect { subject.orcid_update }.to output(/DOI 10.6084\/M9.FIGSHARE.1041547 for ORCID ID 0000-0002-3546-1048 pushed to Profiles service.\n/).to_stdout
    end

    it 'should fail' do
      subject.options = cli_options.except(:access_token)
      expect { subject.orcid_update }.to output("An error occured: Access token missing\n").to_stdout
    end
  end
end
