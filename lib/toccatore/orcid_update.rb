module Toccatore
  class OrcidUpdate < Base
    def source_id
      "orcid_update"
    end

    def q
      "nameIdentifier:ORCID\\:*"
    end

    def cron_line
      ENV['ORCID_UPDATE_CRON_LINE'] || "40 20 * * *"
    end

    def push_url
      "#{ENV['VOLPINO_URL']}/claims"
    end

    def access_token
      ENV['VOLPINO_TOKEN']
    end

    def parse_data(result, options={})
      result = { error: "No hash returned." } unless result.is_a?(Hash)
      return [result] if result[:error]

      items = result.fetch("data", {}).fetch('response', {}).fetch('docs', nil)

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
                     "source_id" => source_id }
          end
          sum
        end
      end
    end

    # push to Volpino API if no error and we have collected works
    def push_data(items, options={})
      return [] if items.empty?

      Array(items).map do |item|
        Maremma.post push_url, data: { "claim" => item }.to_json,
                               token: access_token,
                               content_type: 'json'
      end
    end
  end
end
