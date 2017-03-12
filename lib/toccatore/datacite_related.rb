require_relative 'base'

module Toccatore
  class DataciteRelated < Base
    def source_id
      "datacite_related"
    end

    def query
      "relatedIdentifier:DOI\\:*"
    end

    def parse_data(result)
      return result.body.fetch("errors") if result.body.fetch("errors", nil).present?

      items = result.body.fetch("data", {}).fetch('response', {}).fetch('docs', nil)
      registration_agencies = {}

      Array.wrap(items).reduce([]) do |sum, item|
        doi = item.fetch("doi")
        pid = normalize_doi(doi)
        related_doi_identifiers = item.fetch('relatedIdentifier', []).select { |id| id =~ /:DOI:.+/ }

        # don't generate event if there is a DOI for identical content with same prefix
        skip_doi = related_doi_identifiers.any? do |related_identifier|
          ["IsIdenticalTo"].include?(related_identifier.split(':', 3).first) &&
          related_identifier.split(':', 3).last.to_s.starts_with?(validate_prefix(doi))
        end

        unless skip_doi
          sum += Array(related_doi_identifiers).reduce([]) do |ssum, iitem|
            raw_relation_type, _related_identifier_type, related_identifier = iitem.split(':', 3)
            related_identifier = related_identifier.strip.downcase
            prefix = validate_prefix(related_identifier)
            registration_agencies[prefix] = get_doi_ra(prefix) unless registration_agencies[prefix]

            # check whether this is a DataCite DOI
            if registration_agencies[prefix] == "DataCite"
              ssum
            else
              ssum << { "id" => SecureRandom.uuid,
                        "message_action" => "create",
                        "subj_id" => pid,
                        "obj_id" => normalize_doi(related_identifier),
                        "relation_type_id" => raw_relation_type.underscore,
                        "source_id" => "datacite",
                        "occurred_at" => item.fetch("minted") }
            end
          end
        end

        sum
      end
    end

    def push_item(item, options={})
      return OpenStruct.new(body: { "errors" => [{ "title" => "Access token missing." }] }) if options[:access_token].blank?

      host = options[:push_url].presence || "https://bus.eventdata.crossref.org"
      push_url = host + "/events"

      if host.ends_with?("datacite.org")
        response = Maremma.post(push_url, data: { "data" => item }.to_json,
                                          token: options[:access_token],
                                          content_type: 'json',
                                          host: host)
      else
        response = Maremma.post(push_url, data: item.to_json,
                                          bearer: options[:access_token],
                                          content_type: 'json',
                                          host: host)
      end

      if response.status == 201
        puts "#{item['subj_id']} #{item['relation_type_id']} #{item['obj_id']} pushed to Event Data service."
      elsif response.body["errors"].present?
        puts "An error occured: #{response.body['errors'].first['title']}"
      end
    end
  end
end
