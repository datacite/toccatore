require_relative 'base'

module Toccatore
  class OrcidUpdate < Base
    def source_id
      "orcid_update"
    end

    def q
      "nameIdentifier:ORCID\\:*"
    end

    def parse_data(result, options={})
      return result.body.fetch("errors") if result.body.fetch("errors", nil).present?

      items = result.body.fetch("data", {}).fetch('response', {}).fetch('docs', nil)

      Array(items).reduce([]) do |sum, item|
        doi = item.fetch("doi")
        name_identifiers = item.fetch("nameIdentifier", [])

        if name_identifiers.blank?
          sum
        else
          name_identifiers.each do |name_identifier|
            orcid = name_identifier.split(':', 2).last
            orcid = validate_orcid(orcid)

            next if orcid.blank?

            sum << { "orcid" => orcid,
                     "doi" => doi,
                     "source_id" => source_id,
                     "claim_action"=>"create" }
          end
          sum
        end
      end
    end

    # push to Volpino API if no error and we have collected works
    def push_data(items, options={})
      Array(items).map { |item| push_item(item, options) }
    end

    def push_item(item, options={})
      return OpenStruct.new(body: { "errors" => [{ "title" => "Access token missing." }] }) if options[:access_token].blank?

      push_url = (options[:push_url].presence || "https://profiles.datacite.org/api") + "/claims"

      Maremma.post(push_url, data: { "claim" => item }.to_json,
                             token: options[:access_token],
                             content_type: 'json')
    end
  end
end
