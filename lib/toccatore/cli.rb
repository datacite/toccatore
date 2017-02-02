# encoding: UTF-8

require "thor"
require_relative 'orcid_update'

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
    method_option :from_date, type: :string, default: (Time.now.to_date - 1.day).iso8601
    method_option :until_date, type: :string, default: Time.now.to_date.iso8601
    method_option :query, type: :string
    method_option :orcid, type: :string
    method_option :doi, type: :string
    def orcid_update
      options[:query] = "doi:#{options[:doi]}" if options[:doi].present?
      options[:query] = "nameIdentifier:ORCID\\:#{options[:orcid]}" if options[:orcid].present?

      orcid_update = Toccatore::OrcidUpdate.new
      orcid_update.queue_jobs(options)
    end
  end
end
