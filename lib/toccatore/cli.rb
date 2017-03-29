# encoding: UTF-8

require "thor"

module Toccatore
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    # from http://stackoverflow.com/questions/22809972/adding-a-version-option-to-a-ruby-thor-cli
    map %w[--version -v] => :__print_version

    desc "--version, -v", "print the version"
    def __print_version
      puts Toccatore::VERSION
    end

    desc "orcid_update", "push ORCID IDs from DataCite MDS to ORCID"
    method_option :access_token, type: :string, required: true
    method_option :push_url, type: :string
    method_option :slack_webhook_url, type: :string
    method_option :from_date, type: :string, default: (Time.now.to_date - 1.day).iso8601
    method_option :until_date, type: :string, default: Time.now.to_date.iso8601
    method_option :q, type: :string
    method_option :orcid, type: :string
    method_option :doi, type: :string
    method_option :claim_action, type: :string, default: "create"
    def orcid_update
      orcid_update = Toccatore::OrcidUpdate.new
      orcid_update.queue_jobs(orcid_update.unfreeze(options))
    end

    desc "datacite_related", "push non-DataCite DOIs from DataCite MDS to Event Data"
    method_option :access_token, type: :string, required: true
    method_option :source_token, type: :string, required: true
    method_option :push_url, type: :string
    method_option :slack_webhook_url, type: :string
    method_option :from_date, type: :string, default: (Time.now.to_date - 1.day).iso8601
    method_option :until_date, type: :string, default: Time.now.to_date.iso8601
    method_option :q, type: :string
    method_option :related_identifier, type: :string
    method_option :doi, type: :string
    method_option :jsonapi, :type => :boolean, :force => false
    def datacite_related
      datacite_related = Toccatore::DataciteRelated.new
      datacite_related.queue_jobs(datacite_related.unfreeze(options))
    end
  end
end
