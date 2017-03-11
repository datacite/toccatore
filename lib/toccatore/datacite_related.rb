require_relative 'base'

module Toccatore
  class DataciteRelated < Base
    def source_id
      "datacite_related"
    end

    def query
      "relatedIdentifier:DOI\\:*"
    end

    def parse_data(result, options={})
      return result.body.fetch("errors") if result.body.fetch("errors", nil).present?

      items = result.body.fetch("data", {}).fetch('response', {}).fetch('docs', nil)
      registration_agencies = {}

      Array.wrap(items).reduce([]) do |sum, item|
        doi = item.fetch("doi")
        pid = normalize_doi(doi)
        related_doi_identifiers = item.fetch('relatedIdentifier', []).select { |id| id =~ /:DOI:.+/ }

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

        sum
      end
    end

    # push to Event Data API if no error and we have collected works
    def push_data(items, options={})
      if items.empty?
        puts "No works found for date range #{options[:from_date]} - #{options[:until_date]}."
      elsif options[:access_token].blank?
        puts "An error occured: Access token missing."
      else
        Array(items).each { |item| push_item(item, options) }
      end
    end

    def push_item(item, options={})
      return OpenStruct.new(body: { "errors" => [{ "title" => "Access token missing." }] }) if options[:access_token].blank?

      host = options[:push_url].presence || "https://bus.eventdata.crossref.org"
      push_url = host + "/events"

      response = Maremma.post(push_url, data: item.to_json,
                                        bearer: options[:access_token],
                                        content_type: 'json',
                                        host: host)

      if response.status == 201
        puts "#{item['subj_id']} #{item['relation_type_id']} #{item['obj_id']} pushed to Event Data service."
      elsif response.body["errors"].present?
        puts "An error occured: #{response.body['errors'].first['title']}"
      end
    end
  end
end
