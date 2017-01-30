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
    method_option :from_date, type: :string, default: (Time.now.to_date - 1.day).iso8601
    method_option :until_date, type: :string, default: Time.now.to_date.iso8601
    method_option :push_url, type: :string
    def orcid_update
      orcid_update = Toccatore::OrcidUpdate.new

      data = orcid_update.get_data(options.merge(timeout: orcid_update.timeout, source_id: orcid_update.source_id))
      data = orcid_update.parse_data(data, options.merge(source_id: orcid_update.source_id))

      if data.empty?
        puts "No works found for date range #{options[:from_date]} - #{options[:until_date]}."
      else
        data.each do |item|
          response = orcid_update.push_item(item, options)
          if response.body["data"].present?
            doi = response.body.fetch("data", {}).fetch("attributes", {}).fetch("doi", nil)
            orcid = response.body.fetch("data", {}).fetch("attributes", {}).fetch("orcid", nil)
            puts "DOI #{doi} for ORCID ID #{orcid} pushed to Profiles service."
          elsif response.body["errors"].present?
            puts "An error occured: #{response.body['errors'].first['title']}"
          end
        end
      end
    end
  end
end
